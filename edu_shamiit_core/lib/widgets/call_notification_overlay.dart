import 'package:flutter/material.dart';
import '../services/call_service.dart';
import '../screens/call/call_screen.dart';

/// App-level incoming call notification banner overlay.
/// Wrap your MaterialApp's builder with this widget so incoming
/// calls appear on top of any active route across all roles.
class CallNotificationOverlay extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState>? navigatorKey;

  static GlobalKey<NavigatorState>? globalNavigatorKey;

  const CallNotificationOverlay({
    super.key,
    required this.child,
    this.navigatorKey,
  });

  @override
  State<CallNotificationOverlay> createState() => _CallNotificationOverlayState();
}

class _CallNotificationOverlayState extends State<CallNotificationOverlay>
    with SingleTickerProviderStateMixin {
  final _callService = CallService.instance;
  IncomingCallInfo? _currentIncoming;

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
    );

    _callService.incomingCall.addListener(_onIncomingCallChanged);
  }

  @override
  void dispose() {
    _callService.incomingCall.removeListener(_onIncomingCallChanged);
    _slideController.dispose();
    super.dispose();
  }

  void _onIncomingCallChanged() {
    final incoming = _callService.incomingCall.value;
    if (incoming != null && _currentIncoming == null) {
      setState(() => _currentIncoming = incoming);
      _slideController.forward();
    } else if (incoming == null && _currentIncoming != null) {
      _slideController.reverse().then((_) {
        if (mounted) setState(() => _currentIncoming = null);
      });
    }
  }

  void _accept() {
    final incoming = _currentIncoming;
    if (incoming == null) return;

    _callService.incomingCall.value = null;

    // Answer the call with local media acquisition
    _callService.answerCall(incoming);

    final navState = widget.navigatorKey?.currentState ??
        CallNotificationOverlay.globalNavigatorKey?.currentState;

    if (navState != null) {
      navState.push(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => const CallScreen(),
        ),
      );
    } else {
      try {
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => const CallScreen(),
          ),
        );
      } catch (e) {
        debugPrint('[CallNotificationOverlay] Navigation error: $e');
      }
    }
  }

  void _reject() {
    _callService.rejectIncomingCall();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_currentIncoming != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Overlay(
              initialEntries: [
                OverlayEntry(
                  builder: (ctx) => SlideTransition(
                    position: _slideAnimation,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: _buildBanner(_currentIncoming!),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildBanner(IncomingCallInfo incoming) {
    final isVideo = incoming.callType == CallType.video;
    final initials = incoming.callerName.isNotEmpty
        ? incoming.callerName[0].toUpperCase()
        : '?';

    return Material(
      elevation: 20,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
          border: Border.all(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.6),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2563EB).withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            // Caller Avatar
            Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF2563EB), Color(0xFF06B6D4)],
                ),
              ),
              child: incoming.callerAvatarUrl != null && incoming.callerAvatarUrl!.isNotEmpty
                  ? ClipOval(
                      child: Image.network(
                        incoming.callerAvatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Center(
                          child: Text(
                            initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    )
                  : Center(
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 14),
            // Caller Name & Call Type
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    incoming.callerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: isVideo ? Colors.cyanAccent : Colors.greenAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        incoming.isGroup
                            ? 'Group ${isVideo ? "Video" : "Voice"} Call • ${incoming.groupName ?? "Group"}'
                            : (isVideo
                                ? 'Incoming Video Call...'
                                : 'Incoming Voice Call...'),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Decline Button
            InkWell(
              onTap: _reject,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFFEF4444),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 22),
              ),
            ),
            const SizedBox(width: 10),
            // Accept Button
            InkWell(
              onTap: _accept,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isVideo ? Icons.videocam_rounded : Icons.call_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

