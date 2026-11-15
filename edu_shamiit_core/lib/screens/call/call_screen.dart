import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../services/call_service.dart';

/// Enterprise WebRTC Call Screen
/// Supports both Audio & Video calls with hardware Camera/Microphone streams,
/// Picture-in-Picture (PiP) local preview, Screen Sharing, and Call Duration stopwatch.
class CallScreen extends StatefulWidget {
  const CallScreen({super.key});

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with TickerProviderStateMixin {
  final _callService = CallService.instance;

  final RTCVideoRenderer _localRenderer  = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();

  bool _renderersInitialized = false;

  // Duration timer
  Timer? _durationTimer;
  int _callDurationSecs = 0;

  // Pulse animation for ringing state
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initRenderers();
    _bindCallService();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
    if (!mounted) return;
    setState(() => _renderersInitialized = true);

    _callService.localRenderer  = _localRenderer;
    _callService.remoteRenderer = _remoteRenderer;

    _callService.onLocalStream = (stream) {
      if (mounted) {
        setState(() => _localRenderer.srcObject = stream);
      }
    };
    _callService.onRemoteStream = (stream) {
      if (mounted) {
        setState(() => _remoteRenderer.srcObject = stream);
        _startDurationTimer();
      }
    };
  }

  void _bindCallService() {
    _callService.onCallStateChanged = () {
      if (mounted) {
        final activeCall = _callService.activeCall.value;
        if (activeCall == null) {
          Navigator.of(context).maybePop();
        } else {
          if (activeCall.state == CallState.active && _durationTimer == null) {
            _startDurationTimer();
          }
          setState(() {});
        }
      }
    };
    _callService.onScreenShareChanged = (sharing) {
      if (mounted) setState(() {});
    };
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _callDurationSecs = 0;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _callDurationSecs++);
    });
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _pulseController.dispose();
    _callService.onCallStateChanged = null;
    _callService.onLocalStream = null;
    _callService.onRemoteStream = null;
    _callService.onScreenShareChanged = null;
    _callService.localRenderer = null;
    _callService.remoteRenderer = null;
    if (_renderersInitialized) {
      _localRenderer.dispose();
      _remoteRenderer.dispose();
    }
    super.dispose();
  }

  String _formatDuration(int secs) {
    final m = (secs ~/ 60).toString().padLeft(2, '0');
    final s = (secs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final call = _callService.activeCall.value;
    if (call == null) return const SizedBox.shrink();

    final isVideo   = call.callType == CallType.video;
    final isRinging = call.state == CallState.ringing;
    final isActive  = call.state == CallState.active;
    final initials  = call.peerName.isNotEmpty ? call.peerName[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: SafeArea(
        child: Stack(
          children: [
            // ── Remote Video / Audio Background ────────────────────────
            if (isVideo && _renderersInitialized)
              Positioned.fill(
                child: RTCVideoView(
                  _remoteRenderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                ),
              )
            else
              _buildAudioBackground(isRinging, initials, call.peerName, call.peerAvatarUrl),

            // ── Local Video PiP ────────────────────────────────────────
            if (isVideo && _renderersInitialized && !_callService.isCameraOff)
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  width: 120,
                  height: 170,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white30, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 14,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: RTCVideoView(
                    _localRenderer,
                    mirror: true,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),

            // ── Top Bar: Peer Name + Call Status ───────────────────────
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      call.peerName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive
                            ? Colors.green.withValues(alpha: 0.2)
                            : Colors.blue.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isActive ? Colors.greenAccent : Colors.blueAccent,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        isRinging
                            ? (call.isOutgoing ? 'Calling • Ringing...' : 'Incoming call...')
                            : isActive
                                ? 'Connected • ${_formatDuration(_callDurationSecs)}'
                                : 'Connecting WebRTC...',
                        style: TextStyle(
                          color: isActive ? Colors.greenAccent : Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    if (_callService.isScreenSharing) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.blueAccent.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.blueAccent),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.screen_share, color: Colors.blueAccent, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Screen Sharing Active',
                              style: TextStyle(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ── Bottom Control Bar ─────────────────────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 36),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.9),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Mic Mute / Unmute
                    _buildControlButton(
                      icon: _callService.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      label: _callService.isMuted ? 'Unmute' : 'Mute',
                      color: _callService.isMuted ? Colors.redAccent : Colors.white,
                      background: _callService.isMuted
                          ? Colors.redAccent.withValues(alpha: 0.25)
                          : Colors.white.withValues(alpha: 0.15),
                      onTap: () => setState(() => _callService.toggleMute()),
                    ),
                    if (isVideo) ...[
                      // Camera Toggle
                      _buildControlButton(
                        icon: _callService.isCameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                        label: _callService.isCameraOff ? 'Cam On' : 'Cam Off',
                        color: _callService.isCameraOff ? Colors.redAccent : Colors.white,
                        background: _callService.isCameraOff
                            ? Colors.redAccent.withValues(alpha: 0.25)
                            : Colors.white.withValues(alpha: 0.15),
                        onTap: _callService.toggleCamera,
                      ),
                      // Screen Share
                      _buildControlButton(
                        icon: _callService.isScreenSharing ? Icons.stop_screen_share_rounded : Icons.screen_share_rounded,
                        label: _callService.isScreenSharing ? 'Stop Share' : 'Share',
                        color: _callService.isScreenSharing ? Colors.blueAccent : Colors.white,
                        background: _callService.isScreenSharing
                            ? Colors.blueAccent.withValues(alpha: 0.25)
                            : Colors.white.withValues(alpha: 0.15),
                        onTap: () {
                          if (_callService.isScreenSharing) {
                            _callService.stopScreenShare();
                          } else {
                            _callService.startScreenShare();
                          }
                        },
                      ),
                      // Flip Camera
                      _buildControlButton(
                        icon: Icons.flip_camera_ios_rounded,
                        label: 'Flip',
                        color: Colors.white,
                        background: Colors.white.withValues(alpha: 0.15),
                        onTap: _callService.switchCamera,
                      ),
                    ],
                    // End Call
                    _buildHangupButton(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioBackground(bool isRinging, String initials, String name, String? avatarUrl) {
    return Positioned.fill(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E1B4B), Color(0xFF0F172A), Color(0xFF0A0E21)],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: isRinging ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const RadialGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF1E1B4B)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.5),
                      blurRadius: 36,
                      spreadRadius: 8,
                    ),
                  ],
                  border: Border.all(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.8),
                    width: 3.5,
                  ),
                ),
                child: avatarUrl != null && avatarUrl.isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text(
                              initials,
                              style: const TextStyle(fontSize: 48, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                            fontSize: 48,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              name,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              isRinging ? 'Ringing audio call...' : 'Encrypted WebRTC Audio',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color background,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
              border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.85),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHangupButton(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        await _callService.hangUp();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              color: Colors.redAccent,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.red,
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 6),
          const Text(
            'End Call',
            style: TextStyle(
              color: Colors.redAccent,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
