import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:livekit_client/livekit_client.dart';
import '../../core/services/in_app_live_room_service.dart';
import '../../core/utils/fullscreen_helper.dart';

class InAppLiveRoomScreen extends StatefulWidget {
  final String liveClassId;
  final String currentUserId;
  final String currentUserName;
  final String currentUserRole;
  final String title;

  const InAppLiveRoomScreen({
    super.key,
    required this.liveClassId,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserRole,
    required this.title,
  });

  @override
  State<InAppLiveRoomScreen> createState() => _InAppLiveRoomScreenState();
}

class _InAppLiveRoomScreenState extends State<InAppLiveRoomScreen>
    with TickerProviderStateMixin {
  late InAppLiveRoomService _roomService;
  StreamSubscription? _reactionSubscription;
  StreamSubscription? _controlSubscription;

  bool _isChatOpen = false;
  bool _isParticipantsOpen = false;
  bool _isScreenShareMaximized = false;
  Object? _fullscreenSubscription;
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _chatScrollController = ScrollController();

  // Elapsed session timer
  final Stopwatch _sessionStopwatch = Stopwatch();
  Timer? _timerTick;

  // Floating emoji reaction list
  final List<_FloatingReaction> _reactions = [];

  @override
  void initState() {
    super.initState();
    _roomService = InAppLiveRoomService(
      liveClassId: widget.liveClassId,
      currentUserId: widget.currentUserId,
      currentUserName: widget.currentUserName,
      currentUserRole: widget.currentUserRole,
    );

    _initRoom();

    _fullscreenSubscription = subscribeToFullscreenChanges(() {
      if (mounted && _isScreenShareMaximized) {
        setState(() {
          _isScreenShareMaximized = false;
        });
      }
    });

    _sessionStopwatch.start();
    _timerTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _initRoom() async {
    _roomService.addListener(_onRoomStateChanged);

    // Listen to reactions and administrative kick controls
    _reactionSubscription = _roomService.onReactionReceived.listen((reaction) {
      if (mounted) {
        _addFloatingReaction(reaction['emoji'] as String);
      }
    });

    _controlSubscription = _roomService.onControlReceived.listen((control) {
      if (control['action'] == 'removed' && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('You have been removed from the session by the host.')),
        );
        Navigator.of(context).pop();
      }
    });

    try {
      await _roomService.initializeRoom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join live meeting: $e')),
        );
      }
    }
  }

  void _onRoomStateChanged() {
    if (mounted) {
      setState(() {});
      _scrollChatToBottom();
    }
  }

  void _scrollChatToBottom() {
    if (_chatScrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_chatScrollController.hasClients) {
          _chatScrollController.animateTo(
            _chatScrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _addFloatingReaction(String emoji) {
    final rand = math.Random();
    setState(() {
      _reactions.add(_FloatingReaction(
        emoji: emoji,
        leftOffset: 80 + rand.nextDouble() * 200,
        controller: AnimationController(
          duration: const Duration(milliseconds: 2500),
          vsync: this,
        )..forward().then((_) {
            setState(() {
              _reactions.removeWhere((r) => r.emoji == emoji);
            });
          }),
      ));
    });
  }

  String _formatElapsed(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  void dispose() {
    _reactionSubscription?.cancel();
    _controlSubscription?.cancel();
    _timerTick?.cancel();
    _sessionStopwatch.stop();
    _chatController.dispose();
    _chatScrollController.dispose();
    _roomService.removeListener(_onRoomStateChanged);
    _roomService.dispose();
    for (final r in _reactions) {
      r.controller.dispose();
    }
    unsubscribeFromFullscreenChanges(_fullscreenSubscription);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tracks = _roomService.participantTracks;
    final totalParticipants = tracks.length;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B).withValues(alpha: 0.8),
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.title,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Row(
              children: [
                const Icon(Icons.circle, size: 8, color: Colors.red),
                const SizedBox(width: 6),
                Text(
                  '$totalParticipants in call',
                  style: GoogleFonts.outfit(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  _formatElapsed(_sessionStopwatch.elapsed),
                  style: GoogleFonts.outfit(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
                if (_roomService.isRecording) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.red, width: 0.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.fiber_manual_record,
                            size: 10, color: Colors.red),
                        const SizedBox(width: 4),
                        Text(
                          'REC',
                          style: GoogleFonts.outfit(
                            color: Colors.red,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: FaIcon(
              _isChatOpen
                  ? FontAwesomeIcons.solidComment
                  : FontAwesomeIcons.comment,
              color: _isChatOpen ? const Color(0xFF6366F1) : Colors.white,
            ),
            onPressed: () {
              setState(() {
                _isChatOpen = !_isChatOpen;
                if (_isChatOpen) _isParticipantsOpen = false;
              });
              if (_isChatOpen) _scrollChatToBottom();
            },
          ),
          IconButton(
            icon: Icon(
              Icons.people,
              color:
                  _isParticipantsOpen ? const Color(0xFF6366F1) : Colors.white,
            ),
            onPressed: () {
              setState(() {
                _isParticipantsOpen = !_isParticipantsOpen;
                if (_isParticipantsOpen) _isChatOpen = false;
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Row(
            children: [
              // Main Video Grid
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: _buildVideoGrid(tracks),
                    ),
                    _buildBottomControls(),
                  ],
                ),
              ),
              // Sidebar Panels
              if (_isChatOpen) _buildChatSidebar(),
              if (_isParticipantsOpen) _buildParticipantsSidebar(tracks),
            ],
          ),
          // Floating reactions layer
          ..._reactions.map((reaction) {
            return AnimatedBuilder(
              animation: reaction.controller,
              builder: (context, child) {
                final value = reaction.controller.value;
                final yPos =
                    MediaQuery.of(context).size.height * 0.7 * (1 - value);
                final opacity = (1.0 - value).clamp(0.0, 1.0);
                return Positioned(
                  bottom: 100 + yPos,
                  left: reaction.leftOffset,
                  child: Opacity(
                    opacity: opacity,
                    child: Text(
                      reaction.emoji,
                      style: const TextStyle(fontSize: 48),
                    ),
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildScreenShareCard(LiveKitParticipantTrack track) {
    final showAvatar = track.isCamOff || track.videoTrack == null;
    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent, // Fully transparent to eliminate letterbox background wings
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          // Stream rendering
          if (!showAvatar)
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: VideoTrackRenderer(
                  track.videoTrack!,
                  fit: VideoViewFit.contain,
                  mirrorMode: VideoViewMirrorMode.off, // Screen shares are never mirrored
                ),
              ),
            )
          else
            Center(
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                      width: 1.5),
                ),
                child: Center(
                  child: Text(
                    track.name.isNotEmpty ? track.name[0].toUpperCase() : 'U',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF818CF8),
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          // User Metadata Label Overlay
          Positioned(
            bottom: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    track.isLocal ? 'You (${track.name})' : track.name,
                    style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'SCREEN SHARE',
                      style: GoogleFonts.outfit(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Maximize / Restore Toggle Button Overlay (Bottom-Right)
          Positioned(
            bottom: 12,
            right: 12,
            child: Tooltip(
              message: _isScreenShareMaximized ? 'Exit full screen' : 'View in full screen',
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                    _isScreenShareMaximized ? Icons.fullscreen_exit : Icons.fullscreen,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _isScreenShareMaximized = !_isScreenShareMaximized;
                      toggleBrowserFullscreen(_isScreenShareMaximized);
                    });
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoGrid(List<LiveKitParticipantTrack> tracks) {
    if (tracks.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(color: Color(0xFF6366F1)));
    }

    // Check if any participant is currently sharing screen
    final screenShareTrack = tracks.where((t) => t.isScreenShare).firstOrNull;

    if (screenShareTrack != null) {
      final otherTracks = tracks.where((t) => !t.isScreenShare).toList();
      
      // If maximized, occupy 100% space and hide other camera feeds
      if (_isScreenShareMaximized) {
        return Padding(
          padding: const EdgeInsets.all(8.0),
          child: _buildScreenShareCard(screenShareTrack),
        );
      }

      final isWideScreen = MediaQuery.of(context).size.width > 900;

      if (isWideScreen) {
        // Desktop/Tablet split layout: Screen share on left, vertical cameras on right
        return Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: _buildScreenShareCard(screenShareTrack),
              ),
            ),
            if (otherTracks.isNotEmpty)
              Container(
                width: 220, // Clean width for right sidebar tiles
                padding: const EdgeInsets.only(right: 8, top: 8, bottom: 8),
                child: ListView.builder(
                  scrollDirection: Axis.vertical,
                  itemCount: otherTracks.length,
                  itemBuilder: (context, index) {
                    return AspectRatio(
                      aspectRatio: 1.33,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: _buildVideoCard(otherTracks[index]),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      } else {
        // Portrait/Mobile layout: Screen share on top, horizontal cameras at bottom
        return Column(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: _buildScreenShareCard(screenShareTrack),
              ),
            ),
            if (otherTracks.isNotEmpty)
              SizedBox(
                height: 120, // Compact height
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  itemCount: otherTracks.length,
                  itemBuilder: (context, index) {
                    return Container(
                      width: 160,
                      margin: const EdgeInsets.only(right: 12),
                      child: _buildVideoCard(otherTracks[index]),
                    );
                  },
                ),
              ),
          ],
        );
      }
    }

    // Standard Grid view when no one is sharing screen
    if (tracks.length == 1) {
      return _buildVideoCard(tracks.first);
    }

    final columns = tracks.length <= 2 ? 1 : (tracks.length <= 4 ? 2 : 3);

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.33,
      ),
      itemCount: tracks.length,
      itemBuilder: (context, index) => _buildVideoCard(tracks[index]),
    );
  }

  Widget _buildVideoCard(LiveKitParticipantTrack track) {
    final showAvatar = track.isCamOff || track.videoTrack == null;
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: track.isHandRaised
              ? const Color(0xFFFBBF24)
              : (track.isLocal
                  ? const Color(0xFF6366F1).withValues(alpha: 0.4)
                  : Colors.white10),
          width: track.isHandRaised ? 3 : 2,
        ),
        boxShadow: [
          if (track.isHandRaised)
            BoxShadow(
              color: const Color(0xFFFBBF24).withValues(alpha: 0.2),
              blurRadius: 10,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Stack(
        children: [
          // Stream rendering
          if (!showAvatar)
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: VideoTrackRenderer(
                track.videoTrack!,
                fit: track.isScreenShare ? VideoViewFit.contain : VideoViewFit.cover,
                mirrorMode: track.isLocal && !track.isScreenShare
                    ? VideoViewMirrorMode.mirror
                    : VideoViewMirrorMode.off,
              ),
            )
          else
            Center(
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                      width: 1.5),
                ),
                child: Center(
                  child: Text(
                    track.name.isNotEmpty ? track.name[0].toUpperCase() : 'U',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFF818CF8),
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          // User Metadata Label
          Positioned(
            bottom: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    track.isLocal ? 'You (${track.name})' : track.name,
                    style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                  if (track.role == 'teacher') ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'HOST',
                        style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Indicators Panel
          Positioned(
            top: 10,
            right: 10,
            child: Row(
              children: [
                if (track.isHandRaised)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFBBF24),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.pan_tool,
                        size: 14, color: Colors.black),
                  ),
                if (track.isMicMuted)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.mic_off,
                        size: 14, color: Colors.white),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    final hasHandRaised = _roomService.participantTracks
        .firstWhere((t) => t.isLocal,
            orElse: () => LiveKitParticipantTrack(
                userId: '',
                name: '',
                role: '',
                isLocal: true,
                isMicMuted: false,
                isCamOff: false,
                isHandRaised: false))
        .isHandRaised;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        border: Border(
            top: BorderSide(
                color: Colors.white.withValues(alpha: 0.05), width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Mic Toggle
            _buildRoundButton(
              onPressed: () => _roomService.toggleMic(),
              icon: _roomService.isMicMuted ? Icons.mic_off : Icons.mic,
              backgroundColor: _roomService.isMicMuted
                  ? Colors.red
                  : const Color(0xFF334155),
              iconColor: Colors.white,
              tooltip: _roomService.isMicMuted
                  ? 'Unmute microphone'
                  : 'Mute microphone',
            ),
            const SizedBox(width: 14),
            // Camera Toggle
            _buildRoundButton(
              onPressed: () => _roomService.toggleCamera(),
              icon: _roomService.isCamOff ? Icons.videocam_off : Icons.videocam,
              backgroundColor:
                  _roomService.isCamOff ? Colors.red : const Color(0xFF334155),
              iconColor: Colors.white,
              tooltip: _roomService.isCamOff ? 'Start camera' : 'Stop camera',
            ),
            const SizedBox(width: 14),
            // Screen Share Toggle
            Builder(
              builder: (context) {
                final isSomeoneElseSharing = _roomService.isAnyScreenSharing && !_roomService.isScreenSharing;
                return _buildRoundButton(
                  onPressed: isSomeoneElseSharing
                      ? () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Only one person is allowed to share their screen at a time.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      : () => _roomService.toggleScreenShare(),
                  icon: _roomService.isScreenSharing
                      ? Icons.stop_screen_share
                      : Icons.screen_share,
                  backgroundColor: _roomService.isScreenSharing
                      ? const Color(0xFF10B981)
                      : (isSomeoneElseSharing ? const Color(0xFF1E293B) : const Color(0xFF334155)),
                  iconColor: isSomeoneElseSharing ? Colors.white24 : Colors.white,
                  tooltip: _roomService.isScreenSharing
                      ? 'Stop screen sharing'
                      : (isSomeoneElseSharing ? 'Screen share is currently active by another participant' : 'Share screen'),
                );
              }
            ),
            const SizedBox(width: 14),
            // Hand Raise
            _buildRoundButton(
              onPressed: () => _roomService.toggleHandRaise(),
              icon: Icons.pan_tool,
              backgroundColor: hasHandRaised
                  ? const Color(0xFFFBBF24)
                  : const Color(0xFF334155),
              iconColor: hasHandRaised ? Colors.black : Colors.white,
              tooltip: hasHandRaised ? 'Lower hand' : 'Raise hand',
            ),
            const SizedBox(width: 14),
            // Reactions Popup
            _buildReactionsTrigger(),
            if (widget.currentUserRole == 'teacher') ...[
              const SizedBox(width: 14),
              // Start/Stop Recording (Teacher only)
              _buildRoundButton(
                onPressed: () => _toggleRecording(),
                icon: _roomService.isRecording
                    ? Icons.stop
                    : Icons.fiber_manual_record,
                backgroundColor: _roomService.isRecording
                    ? Colors.red
                    : const Color(0xFF334155),
                iconColor:
                    _roomService.isRecording ? Colors.white : Colors.red,
                tooltip: _roomService.isRecording
                    ? 'Stop recording'
                    : 'Start recording',
              ),
            ],
            const SizedBox(width: 24),
            // Disconnect Call
            _buildRoundButton(
              onPressed: () => _showLeaveConfirmation(),
              icon: Icons.call_end,
              backgroundColor: Colors.red,
              iconColor: Colors.white,
              tooltip: 'Disconnect',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoundButton({
    required VoidCallback onPressed,
    required IconData icon,
    required Color backgroundColor,
    required Color iconColor,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 52,
        height: 52,
        decoration:
            BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(26),
            onTap: onPressed,
            child: Icon(icon, color: iconColor, size: 22),
          ),
        ),
      ),
    );
  }

  Widget _buildReactionsTrigger() {
    return PopupMenuButton<String>(
      onSelected: (emoji) => _roomService.sendReaction(emoji),
      icon: Container(
        width: 52,
        height: 52,
        decoration: const BoxDecoration(
            color: Color(0xFF334155), shape: BoxShape.circle),
        child: const Center(
            child: Icon(Icons.insert_emoticon, color: Colors.white, size: 22)),
      ),
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      itemBuilder: (context) => [
        const PopupMenuItem(
            value: '👏',
            child: Text('👏 Clap',
                style: TextStyle(fontSize: 16, color: Colors.white))),
        const PopupMenuItem(
            value: '👍',
            child: Text('👍 Thumbs Up',
                style: TextStyle(fontSize: 16, color: Colors.white))),
        const PopupMenuItem(
            value: '❤️',
            child: Text('❤️ Heart',
                style: TextStyle(fontSize: 16, color: Colors.white))),
        const PopupMenuItem(
            value: '🎉',
            child: Text('🎉 Celebrate',
                style: TextStyle(fontSize: 16, color: Colors.white))),
      ],
    );
  }

  Widget _buildChatSidebar() {
    return Container(
      width: 340,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        border: Border(
            left: BorderSide(
                color: Colors.white.withValues(alpha: 0.05), width: 1)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              border: Border(
                  bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.05), width: 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Messages',
                  style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
                IconButton(
                  icon:
                      const Icon(Icons.close, color: Colors.white70, size: 20),
                  onPressed: () => setState(() => _isChatOpen = false),
                ),
              ],
            ),
          ),
          // Messages Feed
          Expanded(
            child: _roomService.chatMessages.isEmpty
                ? Center(
                    child: Text('No messages yet',
                        style: GoogleFonts.outfit(color: Colors.white38)),
                  )
                : ListView.builder(
                    controller: _chatScrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _roomService.chatMessages.length,
                    itemBuilder: (context, index) {
                      final msg = _roomService.chatMessages[index];
                      final isSystem = msg.senderRole == 'system';
                      if (isSystem) {
                        return _buildSystemMessageItem(msg.text);
                      }
                      final isMe = msg.senderId == widget.currentUserId;
                      return _buildChatMessageItem(msg, isMe);
                    },
                  ),
          ),
          // Chat Input bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              border: Border(
                  top: BorderSide(
                      color: Colors.white.withValues(alpha: 0.05), width: 1)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _chatController,
                      style:
                          GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Send message...',
                        hintStyle: GoogleFonts.outfit(
                            color: Colors.white30, fontSize: 14),
                        border: InputBorder.none,
                        isDense: true,
                        filled: false,
                      ),
                      onSubmitted: (_) => _sendChatMessage(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send,
                      color: Color(0xFF6366F1), size: 20),
                  onPressed: _sendChatMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatMessageItem(LiveRoomChatMessage msg, bool isMe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment:
            isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isMe ? 'You' : msg.senderName,
                style: GoogleFonts.outfit(
                  color: isMe ? const Color(0xFF818CF8) : Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '(${msg.senderRole})',
                style: GoogleFonts.outfit(color: Colors.white38, fontSize: 9),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFF6366F1) : const Color(0xFF334155),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(12),
                topRight: const Radius.circular(12),
                bottomLeft: Radius.circular(isMe ? 12 : 0),
                bottomRight: Radius.circular(isMe ? 0 : 12),
              ),
            ),
            child: Text(
              msg.text,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemMessageItem(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          text,
          style: GoogleFonts.outfit(
              color: Colors.white38, fontSize: 11, fontStyle: FontStyle.italic),
        ),
      ),
    );
  }

  void _sendChatMessage() {
    final text = _chatController.text.trim();
    if (text.isNotEmpty) {
      _roomService.sendChatMessage(text);
      _chatController.clear();
      _scrollChatToBottom();
    }
  }

  Widget _buildParticipantsSidebar(List<LiveKitParticipantTrack> tracks) {
    final isTeacher = widget.currentUserRole == 'teacher';
    return Container(
      width: 340,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        border: Border(
            left: BorderSide(
                color: Colors.white.withValues(alpha: 0.05), width: 1)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              border: Border(
                  bottom: BorderSide(
                      color: Colors.white.withValues(alpha: 0.05), width: 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Participants',
                  style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
                IconButton(
                  icon:
                      const Icon(Icons.close, color: Colors.white70, size: 20),
                  onPressed: () => setState(() => _isParticipantsOpen = false),
                ),
              ],
            ),
          ),
          // Participants List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: tracks.length,
              itemBuilder: (context, index) {
                final t = tracks[index];
                return ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  leading: CircleAvatar(
                    backgroundColor: t.role == 'teacher'
                        ? Colors.red
                        : const Color(0xFF475569),
                    child: Text(
                        t.name.isNotEmpty ? t.name[0].toUpperCase() : 'U',
                        style: const TextStyle(color: Colors.white)),
                  ),
                  title: Text(
                    t.isLocal ? '${t.name} (You)' : t.name,
                    style: GoogleFonts.outfit(
                        color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    t.role == 'teacher' ? 'Host' : 'Student',
                    style:
                        GoogleFonts.outfit(color: Colors.white54, fontSize: 12),
                  ),
                  trailing: isTeacher && !t.isLocal
                      ? PopupMenuButton<String>(
                          onSelected: (action) {
                            if (action == 'mute') {
                              _roomService.muteStudent(t.userId);
                            } else if (action == 'disable_cam') {
                              _roomService.disableStudentCamera(t.userId);
                            } else if (action == 'remove') {
                              _roomService.removeStudent(t.userId);
                            }
                          },
                          icon: const Icon(Icons.more_vert,
                              color: Colors.white70),
                          color: const Color(0xFF1E293B),
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                                value: 'mute',
                                child: Text('Mute Microphone',
                                    style: TextStyle(color: Colors.white))),
                            const PopupMenuItem(
                                value: 'disable_cam',
                                child: Text('Disable Camera',
                                    style: TextStyle(color: Colors.white))),
                            const PopupMenuItem(
                                value: 'remove',
                                child: Text('Remove from Class',
                                    style: TextStyle(color: Colors.red))),
                          ],
                        )
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showLeaveConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: Text(
          'Leave Live Class?',
          style: GoogleFonts.outfit(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          widget.currentUserRole == 'teacher'
              ? 'Ending this call will stop broadcasting, save the recording, and mark the session as Completed.'
              : 'Are you sure you want to disconnect from this live class?',
          style: GoogleFonts.outfit(color: Colors.white70),
        ),
        actions: [
          TextButton(
            child: Text('Cancel',
                style: GoogleFonts.outfit(color: Colors.white38)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              widget.currentUserRole == 'teacher' ? 'End & Save' : 'Leave',
              style: GoogleFonts.outfit(color: Colors.white),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await _roomService.leaveRoom();
              if (mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _toggleRecording() async {
    try {
      if (_roomService.isRecording) {
        await _roomService.stopRecording();
      } else {
        await _roomService.startRecording();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update recording: $e')),
        );
      }
    }
  }
}

class _FloatingReaction {
  final String emoji;
  final double leftOffset;
  final AnimationController controller;

  _FloatingReaction({
    required this.emoji,
    required this.leftOffset,
    required this.controller,
  });
}
