import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:uuid/uuid.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';

/// Class representing a chat message in the live meeting room
class LiveRoomChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String senderRole;
  final String text;
  final DateTime time;

  LiveRoomChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.text,
    required this.time,
  });

  factory LiveRoomChatMessage.fromJson(Map<String, dynamic> json) {
    return LiveRoomChatMessage(
      id: json['id'] ?? '',
      senderId: json['sender_id'] ?? '',
      senderName: json['sender_name'] ?? 'Unknown',
      senderRole: json['sender_role'] ?? 'student',
      text: json['text'] ?? '',
      time:
          json['time'] != null ? DateTime.parse(json['time']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'sender_name': senderName,
      'sender_role': senderRole,
      'text': text,
      'time': time.toIso8601String(),
    };
  }
}

/// Participant track wrapper for video grid rendering
class LiveKitParticipantTrack {
  final String userId;
  final String name;
  final String role;
  final VideoTrack? videoTrack;
  final bool isLocal;
  final bool isMicMuted;
  final bool isCamOff;
  final bool isHandRaised;
  final bool isScreenShare;

  LiveKitParticipantTrack({
    required this.userId,
    required this.name,
    required this.role,
    this.videoTrack,
    required this.isLocal,
    required this.isMicMuted,
    required this.isCamOff,
    required this.isHandRaised,
    this.isScreenShare = false,
  });
}

/// Service to manage LiveKit room lifecycle, media controls, and real-time signaling
class InAppLiveRoomService extends ChangeNotifier {
  final String liveClassId;
  final String currentUserId;
  final String currentUserName;
  final String currentUserRole; // 'student' or 'teacher'

  Room? _room;
  bool _isScreenSharing = false;
  bool _isMicMuted = false;
  bool _isCamOff = false;
  bool _isRecording = false;

  ConnectionQuality? _lastConnectionQuality;
  DateTime? _lastCongestionAlertTime;

  final List<LiveRoomChatMessage> _chatMessages = [];
  final Set<String> _raisedHands = {};

  // Streams for real-time reactions and host commands
  final _reactionStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _controlStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _roomUpdateController = StreamController<void>.broadcast();

  // Getters
  bool get isScreenSharing => _isScreenSharing;
  bool get isMicMuted => _isMicMuted;
  bool get isCamOff => _isCamOff;

  /// Check if any participant (local or remote) is currently sharing their screen
  bool get isAnyScreenSharing {
    if (_room == null) return false;
    
    // Check local participant
    final localScreenPub = _room!.localParticipant?.videoTrackPublications
        .where((p) => p.source == TrackSource.screenShareVideo)
        .firstOrNull;
    if (localScreenPub != null && !localScreenPub.muted) {
      return true;
    }

    // Check remote participants
    for (final p in _room!.remoteParticipants.values) {
      final screenPub = p.videoTrackPublications
          .where((pub) => pub.source == TrackSource.screenShareVideo)
          .firstOrNull;
      if (screenPub != null && screenPub.subscribed && !screenPub.muted) {
        return true;
      }
    }
    return false;
  }
  bool get isRecording => _isRecording;
  List<LiveRoomChatMessage> get chatMessages => _chatMessages;
  Stream<Map<String, dynamic>> get onReactionReceived =>
      _reactionStreamController.stream;
  Stream<Map<String, dynamic>> get onControlReceived =>
      _controlStreamController.stream;
  Stream<void> get onRoomUpdate => _roomUpdateController.stream;

  Room? get room => _room;

  InAppLiveRoomService({
    required this.liveClassId,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserRole,
  });

  /// Get list of active participant tracks (local + remote) for grid view
  List<LiveKitParticipantTrack> get participantTracks {
    final tracks = <LiveKitParticipantTrack>[];
    if (_room == null) return tracks;

    // 1. Add Local Participant
    final localPart = _room?.localParticipant;
    if (localPart != null) {
      final camPub = localPart.videoTrackPublications
          .where((p) => p.source == TrackSource.camera)
          .firstOrNull;
      final screenPub = localPart.videoTrackPublications
          .where((p) => p.source == TrackSource.screenShareVideo)
          .firstOrNull;

      final localVideo = camPub?.track as VideoTrack? ??
          (screenPub == null ? localPart.videoTrackPublications.firstOrNull?.track as VideoTrack? : null);

      tracks.add(LiveKitParticipantTrack(
        userId: currentUserId,
        name: currentUserName,
        role: currentUserRole,
        videoTrack: localVideo,
        isLocal: true,
        isMicMuted: _isMicMuted,
        isCamOff: _isCamOff,
        isHandRaised: _raisedHands.contains(currentUserId),
        isScreenShare: false,
      ));

      if (screenPub != null && screenPub.track != null) {
        tracks.add(LiveKitParticipantTrack(
          userId: '${currentUserId}_screen',
          name: '$currentUserName\'s Screen',
          role: currentUserRole,
          videoTrack: screenPub.track as VideoTrack?,
          isLocal: true,
          isMicMuted: true,
          isCamOff: false,
          isHandRaised: false,
          isScreenShare: true,
        ));
      }
    }

    // 2. Add Remote Participants
    _room?.remoteParticipants.forEach((peerId, remotePart) {
      final role = remotePart.metadata ?? 'student';
      final name = remotePart.name;
      
      final camPub = remotePart.videoTrackPublications
          .where((p) => p.source == TrackSource.camera)
          .firstOrNull;
      final screenPub = remotePart.videoTrackPublications
          .where((p) => p.source == TrackSource.screenShareVideo)
          .firstOrNull;

      final video = camPub?.track as VideoTrack? ??
          (screenPub == null ? remotePart.videoTrackPublications.firstOrNull?.track as VideoTrack? : null);

      final micMuted =
          !(remotePart.audioTrackPublications.firstOrNull?.subscribed ??
                  false) ||
              (remotePart.audioTrackPublications.firstOrNull?.muted ?? true);
      final camOff = camPub == null ||
          !camPub.subscribed ||
          camPub.muted;

      tracks.add(LiveKitParticipantTrack(
        userId: peerId,
        name: name,
        role: role,
        videoTrack: video,
        isLocal: false,
        isMicMuted: micMuted,
        isCamOff: camOff,
        isHandRaised: _raisedHands.contains(peerId),
        isScreenShare: false,
      ));

      if (screenPub != null && screenPub.subscribed && !screenPub.muted && screenPub.track != null) {
        tracks.add(LiveKitParticipantTrack(
          userId: '${peerId}_screen',
          name: '$name\'s Screen',
          role: role,
          videoTrack: screenPub.track as VideoTrack?,
          isLocal: false,
          isMicMuted: true,
          isCamOff: false,
          isHandRaised: false,
          isScreenShare: true,
        ));
      }
    });

    return tracks;
  }

  /// Initialize and connect to LiveKit SFU
  Future<void> initializeRoom() async {
    try {
      final apiService = ApiService();

      // 1. Mark live class as started in DB (if teacher)
      if (currentUserRole == 'teacher') {
        try {
          await apiService.post('/live-classes/$liveClassId/start', {});
        } catch (e) {
          debugPrint(
              '[LiveKitService] Warning: Failed to start session on backend: $e');
        }
      } else {
        // Log student join log
        try {
          await apiService.post(
              '/live-classes/$liveClassId/attendance/mark', {'action': 'join'});
        } catch (_) {}
      }

      // 2. Fetch JWT Join Token from backend
      final tokenResponse = await apiService.get(
          '/livekit/token?room=$liveClassId&identity=$currentUserId&name=$currentUserName');
      final String token = tokenResponse['token'];
      _isRecording = tokenResponse['is_recording'] ?? false;
      // Map internal Docker hostname (livekit:7880) → localhost:7880 so the browser can reach it.
      // The backend returns LIVEKIT_URL which is an internal Docker network address.
      String sfuUrl = tokenResponse['livekit_url'] ?? 'ws://localhost:7880';
      if (sfuUrl.contains('//livekit:')) {
        sfuUrl = sfuUrl.replaceAll('//livekit:', '//localhost:');
      }
      // LiveKit SDK expects ws:// or wss:// scheme for WebSocket connections
      if (sfuUrl.startsWith('http://')) {
        sfuUrl = sfuUrl.replaceFirst('http://', 'ws://');
      } else if (sfuUrl.startsWith('https://')) {
        sfuUrl = sfuUrl.replaceFirst('https://', 'wss://');
      }
      debugPrint('[LiveKitService] Connecting to SFU: $sfuUrl');

      // Connect to LiveKit Room with optimized HD quality settings
      _room = Room(
        roomOptions: RoomOptions(
          // ─── Camera: Capture in 1080p for teacher (pristine clarity) and 720p for students ───
          defaultCameraCaptureOptions: const CameraCaptureOptions(
            cameraPosition: CameraPosition.front,
            params: VideoParametersPresets.h720_169, // Default capture preset; overridden dynamically on publish
          ),
          // ─── Video Publish: High bitrate VP8/VP9 for maximum quality ───────────────────
          defaultVideoPublishOptions: VideoPublishOptions(
            // Use H.264 for hardware-accelerated rendering and native compression compatibility
            videoCodec: 'h264',
            degradationPreference: DegradationPreference.maintainResolution,
            videoEncoding: VideoEncoding(
              maxBitrate: currentUserRole == 'teacher'
                  ? 3000 * 1000 // 3.0 Mbps max for teacher (supports 1080p stream if available)
                  : 1500 * 1000, // 1.5 Mbps max for student (720p stream)
              maxFramerate: 30,
            ),
            simulcast: true, // Enable simulcast for smart runtime quality adaptation
            videoSimulcastLayers: const [], // Empty = auto compute optimal layers based on input resolution
            // 3 Mbps for screen share — content-heavy, needs more bitrate
            screenShareEncoding: const VideoEncoding(
              maxBitrate: 3000 * 1000,
              maxFramerate: 30,
            ),
            // Empty = no simulcast for screen share (not beneficial for slides/code)
            screenShareSimulcastLayers: const [],
          ),
          // ─── Audio Publish: High-quality OPUS ────────────────────────────────
          defaultAudioPublishOptions: const AudioPublishOptions(
            // AudioPreset.musicHighQuality = 96000 bps — broadcast quality
            audioBitrate: AudioPreset.musicHighQuality,
            dtx: true, // Discontinuous transmission saves bandwidth on silence
          ),
          // ─── Audio Capture: Noise suppression + echo cancel ──────────────────
          defaultAudioCaptureOptions: const AudioCaptureOptions(
            echoCancellation: true,
            noiseSuppression: true,
            autoGainControl: true,
          ),
          // ─── Screen Share: Full HD @ 30fps ───────────────────────────────────
          defaultScreenShareCaptureOptions: const ScreenShareCaptureOptions(
            params: VideoParametersPresets.screenShareH1080FPS30,
          ),
          // ─── Adaptive streaming and dynacast ─────────────────────────────────
          adaptiveStream: true, // Auto-downgrade video quality for slow viewers
          dynacast: true, // Pause layers not rendered by any subscriber
        ),
      );

      // Room Event Listeners
      final listener = _room!.createListener();
      listener.on<RoomEvent>((event) {
        _handleRoomEvent(event);
      });

      // Connect to room using LiveKit URL
      await _room!.connect(sfuUrl, token);

      // Enable camera and microphone automatically on join
      await _room?.localParticipant?.setMicrophoneEnabled(true);
      await _publishCameraWithFallback();

      // Load chat history from database backend
      try {
        final chatResponse =
            await apiService.get('/live-classes/$liveClassId/chat');
        final List chats = chatResponse['data']['chats'] ?? [];
        _chatMessages.clear();
        for (final c in chats) {
          _chatMessages.add(LiveRoomChatMessage.fromJson(c));
        }
      } catch (_) {}

      // System message: recording starts
      if (_isRecording) {
        _addSystemMessage("Recording Started");
      }

      notifyListeners();
      _roomUpdateController.add(null);
    } catch (e) {
      debugPrint('[LiveKitService] Error connecting to room: $e');
      rethrow;
    }
  }

  /// Toggle microphone
  Future<void> toggleMic() async {
    if (_room == null) return;
    _isMicMuted = !_isMicMuted;
    await _room?.localParticipant?.setMicrophoneEnabled(!_isMicMuted);
    notifyListeners();
    _roomUpdateController.add(null);
  }

  /// Toggle camera
  Future<void> toggleCamera() async {
    if (_room == null) return;
    _isCamOff = !_isCamOff;
    if (_isCamOff) {
      await _room?.localParticipant?.setCameraEnabled(false);
    } else {
      await _publishCameraWithFallback();
    }
    notifyListeners();
    _roomUpdateController.add(null);
  }

  /// Publishes the camera with fallback options for older or lower-end devices.
  /// First, it tries the requested high resolution (e.g. 1080p for teacher).
  /// If that fails, it falls back to 720p.
  /// If that also fails, it falls back to default settings/resolution.
  Future<void> _publishCameraWithFallback() async {
    final localParticipant = _room?.localParticipant;
    if (localParticipant == null) return;

    if (_isCamOff) {
      await localParticipant.setCameraEnabled(false);
      return;
    }

    final List<VideoParameters> resolutionSequence = [];

    if (currentUserRole == 'teacher') {
      resolutionSequence.addAll([
        VideoParametersPresets.h1080_169,
        VideoParametersPresets.h720_169,
        VideoParametersPresets.h540_169,
      ]);
    } else {
      resolutionSequence.addAll([
        VideoParametersPresets.h720_169,
        VideoParametersPresets.h540_169,
      ]);
    }

    bool success = false;
    for (final preset in resolutionSequence) {
      try {
        debugPrint('[LiveKitService] Attempting camera publish with preset: ${preset.dimensions.width}x${preset.dimensions.height}');
        await localParticipant.setCameraEnabled(
          true,
          cameraCaptureOptions: CameraCaptureOptions(
            cameraPosition: CameraPosition.front,
            params: preset,
          ),
        );
        debugPrint('[LiveKitService] Camera successfully published with preset: ${preset.dimensions.width}x${preset.dimensions.height}');
        success = true;
        break;
      } catch (e) {
        debugPrint('[LiveKitService] Failed to publish camera with preset (${preset.dimensions.width}x${preset.dimensions.height}): $e');
      }
    }

    if (!success) {
      debugPrint('[LiveKitService] Attempting default camera fallback');
      try {
        await localParticipant.setCameraEnabled(true);
        debugPrint('[LiveKitService] Camera successfully published with default settings');
      } catch (e) {
        debugPrint('[LiveKitService] Failed to publish camera even with default settings: $e');
        _isCamOff = true;
        _safeNotify();
        _safeRoomUpdate();
      }
    }
  }

  /// Toggle Screen Sharing
  Future<void> toggleScreenShare() async {
    if (_room == null) return;

    if (!_isScreenSharing && isAnyScreenSharing) {
      debugPrint('[LiveKitService] Prevented screen share: Another participant is already sharing.');
      return;
    }

    _isScreenSharing = !_isScreenSharing;
    await _room?.localParticipant?.setScreenShareEnabled(_isScreenSharing);
    notifyListeners();
    _roomUpdateController.add(null);
  }

  /// Toggle hand raised status
  Future<void> toggleHandRaise() async {
    if (_room == null) return;
    final isRaised = !_raisedHands.contains(currentUserId);
    if (isRaised) {
      _raisedHands.add(currentUserId);
    } else {
      _raisedHands.remove(currentUserId);
    }

    // Broadcast update via Data Channel
    await _broadcastData(
        {'type': 'hand_raise', 'userId': currentUserId, 'isRaised': isRaised});

    notifyListeners();
    _roomUpdateController.add(null);
  }

  /// Send emoji reaction to all participants
  Future<void> sendReaction(String emoji) async {
    if (_room == null) return;

    // Broadcast emoji
    await _broadcastData(
        {'type': 'reaction', 'userId': currentUserId, 'emoji': emoji});

    // Also trigger locally
    _reactionStreamController.add({'userId': currentUserId, 'emoji': emoji});
  }

  /// Send chat message
  Future<void> sendChatMessage(String text) async {
    if (_room == null || text.trim().isEmpty) return;

    final msgId = const Uuid().v4();
    final message = LiveRoomChatMessage(
      id: msgId,
      senderId: currentUserId,
      senderName: currentUserName,
      senderRole: currentUserRole,
      text: text,
      time: DateTime.now(),
    );

    // Save chat message in database
    final apiService = ApiService();
    try {
      await apiService
          .post('/live-classes/$liveClassId/chat', {'message': text});
    } catch (_) {}

    // Broadcast message to LiveKit Room
    await _broadcastData({'type': 'chat', 'message': message.toJson()});

    _chatMessages.add(message);
    _safeNotify();
    _safeRoomUpdate();
  }

  /// Mute a specific student (Teacher Only)
  Future<void> muteStudent(String targetUserId) async {
    if (currentUserRole != 'teacher') return;
    await _broadcastData({
      'type': 'control',
      'targetUserId': targetUserId,
      'action': 'mute_mic'
    });
  }

  /// Disable student's camera (Teacher Only)
  Future<void> disableStudentCamera(String targetUserId) async {
    if (currentUserRole != 'teacher') return;
    await _broadcastData({
      'type': 'control',
      'targetUserId': targetUserId,
      'action': 'disable_camera'
    });
  }

  /// Remove student from room (Teacher Only)
  Future<void> removeStudent(String targetUserId) async {
    if (currentUserRole != 'teacher') return;
    await _broadcastData(
        {'type': 'control', 'targetUserId': targetUserId, 'action': 'remove'});
  }

  /// Helper to send JSON dictionary via LiveKit Room Data Channel
  Future<void> _broadcastData(Map<String, dynamic> data) async {
    if (_room == null) return;
    try {
      final bytes = utf8.encode(json.encode(data));
      await _room?.localParticipant?.publishData(
        Uint8List.fromList(bytes),
        reliable: true,
      );
    } catch (e) {
      debugPrint('[LiveKitService] Error broadcasting data: $e');
    }
  }

  /// Handler for room events (subscribes, syncs, and data packets)
  void _handleRoomEvent(RoomEvent event) {
    if (_isDisposed) return; // Ignore events after service is disposed
    if (event is TrackSubscribedEvent ||
        event is TrackUnsubscribedEvent ||
        event is ParticipantConnectedEvent ||
        event is ParticipantDisconnectedEvent) {
      if (event is ParticipantConnectedEvent) {
        final pName = event.participant.name;
        _addSystemMessage("${pName.isEmpty ? 'Student' : pName} Joined");
      } else if (event is ParticipantDisconnectedEvent) {
        final pName = event.participant.name;
        _addSystemMessage("${pName.isEmpty ? 'Student' : pName} Left");
      }
      _safeNotify();
      _safeRoomUpdate();
    } else if (event is ParticipantConnectionQualityUpdatedEvent) {
      if (event.participant.identity == currentUserId) {
        _handleConnectionQualityChange(event.connectionQuality);
      }
    } else if (event is DataReceivedEvent) {
      try {
        final decoded = json.decode(utf8.decode(event.data));
        final type = decoded['type'] as String?;

        if (type == 'chat') {
          final msg = LiveRoomChatMessage.fromJson(decoded['message']);
          _chatMessages.add(msg);
          _safeNotify();
          _safeRoomUpdate();
        } else if (type == 'hand_raise') {
          final uId = decoded['userId'] as String;
          final isRaised = decoded['isRaised'] as bool;
          if (isRaised) {
            _raisedHands.add(uId);
          } else {
            _raisedHands.remove(uId);
          }
          _safeNotify();
          _safeRoomUpdate();
        } else if (type == 'reaction') {
          if (!_reactionStreamController.isClosed) {
            _reactionStreamController
                .add({'userId': decoded['userId'], 'emoji': decoded['emoji']});
          }
        } else if (type == 'control') {
          final target = decoded['targetUserId'] as String;
          final action = decoded['action'] as String;
          if (target == currentUserId) {
            _handleHostControlAction(action);
          }
        } else if (type == 'recording_status') {
          final isRec = decoded['isRecording'] as bool? ?? false;
          if (isRec != _isRecording) {
            _isRecording = isRec;
            _addSystemMessage(isRec ? "Recording Started" : "Recording Stopped");
            _safeNotify();
            _safeRoomUpdate();
          }
        }
      } catch (e) {
        debugPrint('[LiveKitService] Error parsing data packet: $e');
      }
    }
  }

  /// Handle incoming administrative commands from host
  void _handleHostControlAction(String action) {
    if (_isDisposed) return;
    if (action == 'mute_mic') {
      if (!_isMicMuted) toggleMic();
    } else if (action == 'disable_camera') {
      if (!_isCamOff) toggleCamera();
    } else if (action == 'remove') {
      if (!_controlStreamController.isClosed) {
        _controlStreamController.add({'action': 'removed'});
      }
      leaveRoom();
    }
  }

  /// Handle connection quality changes of the local participant
  void _handleConnectionQualityChange(ConnectionQuality quality) {
    if (quality == _lastConnectionQuality) return;
    _lastConnectionQuality = quality;

    debugPrint('[LiveKitService] Connection quality changed for local participant: $quality');
    if (quality == ConnectionQuality.poor) {
      final now = DateTime.now();
      if (_lastCongestionAlertTime == null || 
          now.difference(_lastCongestionAlertTime!) > const Duration(minutes: 2)) {
        _lastCongestionAlertTime = now;
        debugPrint('[LiveKitService] Smart network decision: Network congestion detected. WebRTC is dynamically scaling down bitrate/resolution.');
        _addSystemMessage("Network congestion detected. Optimizing video streaming quality dynamically.");
        _safeNotify();
        _safeRoomUpdate();
      }
    }
  }

  /// Local system message adder
  bool _isDisposed = false;
  bool _isLeaving = false;

  void _addSystemMessage(String text) {
    if (_isDisposed) return;
    _chatMessages.add(LiveRoomChatMessage(
      id: const Uuid().v4(),
      senderId: 'system',
      senderName: 'System',
      senderRole: 'system',
      text: text,
      time: DateTime.now(),
    ));
  }

  void _safeNotify() {
    if (!_isDisposed) notifyListeners();
  }

  void _safeRoomUpdate() {
    if (!_isDisposed && !_roomUpdateController.isClosed) {
      _roomUpdateController.add(null);
    }
  }

  /// Start recording (Teacher only)
  Future<void> startRecording() async {
    if (currentUserRole != 'teacher') return;
    final apiService = ApiService();
    await apiService.post('/live-classes/$liveClassId/recording/start', {});
    _isRecording = true;
    await _broadcastData({'type': 'recording_status', 'isRecording': true});
    _addSystemMessage("Recording Started");
    _safeNotify();
    _safeRoomUpdate();
  }

  /// Stop recording (Teacher only)
  Future<void> stopRecording() async {
    if (currentUserRole != 'teacher') return;
    final apiService = ApiService();
    await apiService.post('/live-classes/$liveClassId/recording/stop', {});
    _isRecording = false;
    await _broadcastData({'type': 'recording_status', 'isRecording': false});
    _addSystemMessage("Recording Stopped");
    _safeNotify();
    _safeRoomUpdate();
  }

  /// Leave call and clean up connection resources
  Future<void> leaveRoom() async {
    // Prevent concurrent or double calls (e.g. manual leave + dispose)
    if (_isLeaving) return;
    _isLeaving = true;

    try {
      final apiService = ApiService();

      if (currentUserRole == 'teacher') {
        _isRecording = false;
        try {
          await apiService.post('/live-classes/$liveClassId/end', {});
          debugPrint(
              '[LiveKitService] Successfully called end-class endpoint for $liveClassId');
        } catch (e, s) {
          debugPrint(
              '[LiveKitService] Exception calling end-class endpoint for $liveClassId: $e');
          debugPrint('$s');
        }
      } else {
        // Mark student leave log
        try {
          await apiService.post('/live-classes/$liveClassId/attendance/mark',
              {'action': 'leave'});
          debugPrint(
              '[LiveKitService] Successfully marked student leave attendance');
        } catch (e, s) {
          debugPrint('[LiveKitService] Exception marking student leave: $e');
          debugPrint('$s');
        }
      }

      if (_room != null) {
        await _room!.disconnect();
        _room = null;
      }
      _raisedHands.clear();
      _chatMessages.clear();

      _safeNotify();
      _safeRoomUpdate();
    } catch (e) {
      debugPrint('[LiveKitService] Error leaving room: $e');
    } finally {
      _isLeaving = false;
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    // Disconnect synchronously best-effort (fire-and-forget, no await in dispose)
    _room?.disconnect().catchError((_) {});
    _room = null;
    // Close all stream controllers before super.dispose() to prevent late pushes
    if (!_reactionStreamController.isClosed) _reactionStreamController.close();
    if (!_controlStreamController.isClosed) _controlStreamController.close();
    if (!_roomUpdateController.isClosed) _roomUpdateController.close();
    super.dispose();
  }
}
