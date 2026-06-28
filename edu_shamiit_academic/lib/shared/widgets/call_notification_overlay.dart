import 'package:flutter/material.dart';
import 'package:edu_shamiit_academic/core/services/call_service.dart';
import 'package:edu_shamiit_academic/shared/screens/call_screen.dart';
import 'package:edu_shamiit_academic/app_router.dart';

/// App-level incoming call notification banner.
/// Wrap your MaterialApp's builder with this widget so incoming
/// call notifications appear on top of any current route.
class CallNotificationOverlay extends StatefulWidget {
  final Widget child;

  const CallNotificationOverlay({super.key, required this.child});

  @override
  State<CallNotificationOverlay> createState() =>
      _CallNotificationOverlayState();
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
        CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

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

    // Dismiss the banner (listener will clean up)
    _callService.incomingCall.value = null;

    // Answer the call
    _callService.answerCall(incoming);

    // Navigate to call screen
    rootNavigatorKey.currentState?.push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const CallScreen(),
      ),
    );
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
            child: SlideTransition(
              position: _slideAnimation,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: _buildBanner(_currentIncoming!),
                ),
              ),
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
      elevation: 16,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(
            colors: [Color(0xFF1A1D3E), Color(0xFF2D2F6F)],
          ),
          border: Border.all(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.6),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4F46E5).withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
                ),
              ),
              child: incoming.callerAvatarUrl != null
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
                                fontWeight: FontWeight.bold),
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
                            fontWeight: FontWeight.bold),
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    incoming.callerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    isVideo
                        ? '📹 Incoming Video Call'
                        : '📞 Incoming Voice Call',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Reject
            GestureDetector(
              onTap: _reject,
              child: Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.call_end_rounded,
                    color: Colors.white, size: 22),
              ),
            ),
            const SizedBox(width: 8),
            // Accept
            GestureDetector(
              onTap: _accept,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.greenAccent.shade700,
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
