import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:uuid/uuid.dart';
import '../../../services/api_service.dart';

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
      text: json['text'] ?? json['message'] ?? '',
      time: json['time'] != null ? DateTime.parse(json['time']) : DateTime.now(),
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
  final bool isSpeaking;

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
    this.isSpeaking = false,
  });
}

/// Service to manage LiveKit room lifecycle, media controls, and real-time signaling
class InAppLiveRoomService extends ChangeNotifier {
  String liveClassId;
  String currentUserId;
  String currentUserName;
  String currentUserRole; // 'student', 'teacher', 'admin'

  Room? _room;
  bool get isConnected => _room != null;
  Future<void> broadcastData(Map<String, dynamic> data) async => _broadcastData(data);
  bool _isScreenSharing = false;
  bool _isMicMuted = true;
  bool _isCamOff = true;
  bool _isRecording = false;

  ConnectionQuality? _lastConnectionQuality;
  DateTime? _lastCongestionAlertTime;

  final List<LiveRoomChatMessage> _chatMessages = [];
  final Set<String> _raisedHands = {};
  final Map<String, String> _customRoles = {};
  Map<String, String> get customRoles => _customRoles;

  Future<void> assignRole(String userId, String newRole) async {
    _customRoles[userId] = newRole;
    await _broadcastData({
      'type': 'role_assigned',
      'userId': userId,
      'newRole': newRole,
    });
    _safeNotify();
    _safeRoomUpdate();
  }

  final _reactionStreamController = StreamController<Map<String, dynamic>>.broadcast();
  final _controlStreamController = StreamController<Map<String, dynamic>>.broadcast();
  final _roomUpdateController = StreamController<void>.broadcast();

  Timer? _heartbeatTimer;

  bool get isScreenSharing => _isScreenSharing;
  bool get isMicMuted => _isMicMuted;
  bool get isCamOff => _isCamOff;
  bool get isRecording => _isRecording;
  List<LiveRoomChatMessage> get chatMessages => _chatMessages;
  Stream<Map<String, dynamic>> get onReactionReceived => _reactionStreamController.stream;
  Stream<Map<String, dynamic>> get onControlReceived => _controlStreamController.stream;
  Stream<void> get onRoomUpdate => _roomUpdateController.stream;
  Room? get room => _room;
  ConnectionQuality? get lastConnectionQuality => _lastConnectionQuality;
  DateTime? get lastCongestionAlertTime => _lastCongestionAlertTime;

  InAppLiveRoomService({
    this.liveClassId = '',
    this.currentUserId = '',
    this.currentUserName = 'User',
    this.currentUserRole = 'teacher',
  });

  void initRoomConfig({
    required String liveClassId,
    required String currentUserId,
    required String currentUserName,
    required String currentUserRole,
  }) {
    this.liveClassId = liveClassId;
    this.currentUserId = currentUserId;
    this.currentUserName = currentUserName;
    this.currentUserRole = currentUserRole;
    _isMicMuted = true;
    _isCamOff = true;
    _isScreenSharing = false;
    notifyListeners();
  }

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
        isSpeaking: !_isMicMuted,
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
      final assignedRole = _customRoles[peerId];
      final role = assignedRole ?? remotePart.metadata ?? 'student';
      final name = remotePart.name;

      final camPub = remotePart.videoTrackPublications
          .where((p) => p.source == TrackSource.camera)
          .firstOrNull;
      final screenPub = remotePart.videoTrackPublications
          .where((p) => p.source == TrackSource.screenShareVideo)
          .firstOrNull;

      final video = camPub?.track as VideoTrack? ??
          (screenPub == null ? remotePart.videoTrackPublications.firstOrNull?.track as VideoTrack? : null);

      final micMuted = !(remotePart.audioTrackPublications.firstOrNull?.subscribed ?? false) ||
          (remotePart.audioTrackPublications.firstOrNull?.muted ?? true);
      final camOff = camPub == null || !camPub.subscribed || camPub.muted;

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
        isSpeaking: remotePart.isSpeaking,
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

  Future<void> initializeRoom() async {
    try {
      final apiService = ApiService();

      // 1. Backend Join Event
      try {
        await apiService.post('/live-classes/$liveClassId/event', {
          'action': 'join',
          'role': currentUserRole,
          'user_id': currentUserId,
        });
      } catch (e) {
        debugPrint('[LiveKitService] Join event notice: $e');
      }

      // 2. Start heartbeat timer every 30s for resilient attendance tracking
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
        try {
          await apiService.post('/live-classes/$liveClassId/event', {
            'action': 'heartbeat',
            'user_id': currentUserId,
          });
        } catch (_) {}
      });

      // 3. Fetch Token from Backend
      final tokenResponse = await apiService.get(
        '/livekit/token?room=$liveClassId&identity=$currentUserId&name=${Uri.encodeComponent(currentUserName)}'
      );
      final String token = tokenResponse['token'] ?? '';
      _isRecording = tokenResponse['is_recording'] ?? false;
      String sfuUrl = tokenResponse['livekit_url'] ?? 'ws://localhost:8082';

      // Normalize SFU URL for local vs production
      if (kIsWeb) {
        final host = Uri.base.host.isNotEmpty ? Uri.base.host : 'localhost';
        final isLocal = host == 'localhost' || host == '127.0.0.1' || host.startsWith('192.168.');
        if (isLocal && (sfuUrl.contains('eduapi.shamiit.com') || sfuUrl.contains(':7880'))) {
          sfuUrl = 'ws://$host:8082';
        }
      }
      if (sfuUrl.contains('//livekit:')) {
        sfuUrl = sfuUrl.replaceAll('//livekit:', '//localhost:');
      }
      if (sfuUrl.contains(':7880') && !sfuUrl.startsWith('wss://')) {
        sfuUrl = sfuUrl.replaceAll(':7880', ':8082');
      }
      if (sfuUrl.startsWith('http://')) {
        sfuUrl = sfuUrl.replaceFirst('http://', 'ws://');
      } else if (sfuUrl.startsWith('https://')) {
        sfuUrl = sfuUrl.replaceFirst('https://', 'wss://');
      }

      debugPrint('[LiveKitService] Connecting to SFU: $sfuUrl for room: $liveClassId');

      _room = Room(
        roomOptions: RoomOptions(
          defaultCameraCaptureOptions: const CameraCaptureOptions(
            cameraPosition: CameraPosition.front,
            params: VideoParametersPresets.h720_169,
          ),
          defaultVideoPublishOptions: VideoPublishOptions(
            videoCodec: 'h264',
            degradationPreference: DegradationPreference.maintainResolution,
            videoEncoding: VideoEncoding(
              maxBitrate: currentUserRole == 'teacher' ? 3000 * 1000 : 1500 * 1000,
              maxFramerate: 30,
            ),
            simulcast: true,
          ),
          defaultAudioPublishOptions: const AudioPublishOptions(
            dtx: true,
          ),
          defaultAudioCaptureOptions: const AudioCaptureOptions(
            echoCancellation: true,
            noiseSuppression: true,
            autoGainControl: true,
          ),
          defaultScreenShareCaptureOptions: const ScreenShareCaptureOptions(
            params: VideoParametersPresets.screenShareH1080FPS30,
          ),
          adaptiveStream: true,
          dynacast: true,
        ),
      );

      final listener = _room!.createListener();
      listener.on<RoomEvent>((event) {
        _handleRoomEvent(event);
      });

      await _room!.connect(sfuUrl, token);

      // Default state: Camera and Microphone are disabled on join (like Zoom / Google Meet)
      _isMicMuted = true;
      _isCamOff = true;
      _isScreenSharing = false;
      try {
        await _room?.localParticipant?.setMicrophoneEnabled(false);
      } catch (_) {}
      try {
        await _room?.localParticipant?.setCameraEnabled(false);
      } catch (_) {}

      // Load initial chat
      try {
        final chatResponse = await apiService.get('/live-classes/$liveClassId/chat');
        final List chats = chatResponse['data']?['chats'] ?? [];
        _chatMessages.clear();
        for (final c in chats) {
          _chatMessages.add(LiveRoomChatMessage.fromJson(c));
        }
      } catch (_) {}

      if (_isRecording) {
        _addSystemMessage("Recording in progress");
      }

      notifyListeners();
      _roomUpdateController.add(null);
    } catch (e) {
      debugPrint('[LiveKitService] Error connecting: $e');
      rethrow;
    }
  }

  Future<bool> toggleMic() async {
    if (_room == null) return false;
    final enable = _isMicMuted;
    try {
      if (!enable) {
        // Turning OFF Microphone -> Completely release microphone hardware
        try {
          await _room?.localParticipant?.setMicrophoneEnabled(
            false,
            audioCaptureOptions: const AudioCaptureOptions(stopAudioCaptureOnMute: true),
          );
        } catch (_) {}

        final localParticipant = _room?.localParticipant;
        if (localParticipant != null) {
          for (final pub in localParticipant.audioTrackPublications) {
            if (pub.source == TrackSource.microphone) {
              try {
                await pub.track?.stop(); // Release browser audio device hardware
              } catch (_) {}
            }
          }
        }
        _isMicMuted = true;
      } else {
        // Turning ON Microphone -> Re-acquire device audio stream
        await _room?.localParticipant?.setMicrophoneEnabled(true);
        _isMicMuted = false;
      }
      notifyListeners();
      _roomUpdateController.add(null);
      return !_isMicMuted;
    } catch (e) {
      debugPrint('[LiveKitService] toggleMic error: $e');
      _isMicMuted = true;
      notifyListeners();
      _roomUpdateController.add(null);
      rethrow;
    }
  }

  Future<bool> toggleCamera() async {
    if (_room == null) return false;
    final enable = _isCamOff;
    if (!enable) {
      // Turning OFF Camera -> Completely release camera sensor and webcam LED
      try {
        await _room?.localParticipant?.setCameraEnabled(
          false,
          cameraCaptureOptions: const CameraCaptureOptions(stopCameraCaptureOnMute: true),
        );
      } catch (_) {}

      final localParticipant = _room?.localParticipant;
      if (localParticipant != null) {
        for (final pub in localParticipant.videoTrackPublications) {
          if (pub.source == TrackSource.camera) {
            try {
              await pub.track?.stop(); // Release browser webcam hardware device
            } catch (_) {}
          }
        }
      }
      _isCamOff = true;
      notifyListeners();
      _roomUpdateController.add(null);
      return false;
    } else {
      // Turning ON Camera -> Re-acquire camera stream
      try {
        _isCamOff = false;
        await _publishCameraWithFallback();
        notifyListeners();
        _roomUpdateController.add(null);
        return true;
      } catch (e) {
        debugPrint('[LiveKitService] toggleCamera error: $e');
        _isCamOff = true;
        notifyListeners();
        _roomUpdateController.add(null);
        rethrow;
      }
    }
  }

  Future<void> _publishCameraWithFallback() async {
    final localParticipant = _room?.localParticipant;
    if (localParticipant == null) return;

    if (_isCamOff) {
      await localParticipant.setCameraEnabled(false);
      return;
    }

    try {
      await localParticipant.setCameraEnabled(
        true,
        cameraCaptureOptions: const CameraCaptureOptions(
          cameraPosition: CameraPosition.front,
          params: VideoParametersPresets.h720_169,
        ),
      );
    } catch (e) {
      try {
        await localParticipant.setCameraEnabled(true);
      } catch (_) {
        _isCamOff = true;
        rethrow;
      }
    }
  }

  Future<bool> toggleScreenShare() async {
    if (_room == null) return false;
    final enable = !_isScreenSharing;
    try {
      await _room?.localParticipant?.setScreenShareEnabled(enable);
      _isScreenSharing = enable;
      notifyListeners();
      _roomUpdateController.add(null);
      return enable;
    } catch (e) {
      debugPrint('[LiveKitService] toggleScreenShare error: $e');
      _isScreenSharing = false;
      notifyListeners();
      _roomUpdateController.add(null);
      rethrow;
    }
  }

  Future<void> toggleHandRaise() async {
    if (_room == null) return;
    final isRaised = !_raisedHands.contains(currentUserId);
    if (isRaised) {
      _raisedHands.add(currentUserId);
    } else {
      _raisedHands.remove(currentUserId);
    }
    await _broadcastData({'type': 'hand_raise', 'userId': currentUserId, 'isRaised': isRaised});
    notifyListeners();
    _roomUpdateController.add(null);
  }

  Future<void> sendReaction(String emoji) async {
    if (_room == null) return;
    await _broadcastData({'type': 'reaction', 'userId': currentUserId, 'emoji': emoji});
    _reactionStreamController.add({'userId': currentUserId, 'emoji': emoji});
  }

  Future<void> sendChatMessage(String text) async {
    if (_room == null || text.trim().isEmpty) return;
    final msg = LiveRoomChatMessage(
      id: const Uuid().v4(),
      senderId: currentUserId,
      senderName: currentUserName,
      senderRole: currentUserRole,
      text: text,
      time: DateTime.now(),
    );

    try {
      final apiService = ApiService();
      await apiService.post('/live-classes/$liveClassId/chat', {'message': text});
    } catch (_) {}

    await _broadcastData({'type': 'chat', 'message': msg.toJson()});
    _chatMessages.add(msg);
    _safeNotify();
    _safeRoomUpdate();
  }

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

  void _handleRoomEvent(RoomEvent event) {
    if (_isDisposed) return;
    if (event is TrackSubscribedEvent ||
        event is TrackUnsubscribedEvent ||
        event is TrackPublishedEvent ||
        event is TrackUnpublishedEvent ||
        event is LocalTrackPublishedEvent ||
        event is LocalTrackUnpublishedEvent ||
        event is TrackMutedEvent ||
        event is TrackUnmutedEvent ||
        event is TrackStreamStateUpdatedEvent ||
        event is ActiveSpeakersChangedEvent ||
        event is ParticipantConnectedEvent ||
        event is ParticipantDisconnectedEvent) {
      if (event is ParticipantConnectedEvent) {
        _addSystemMessage("${event.participant.name} Joined");
      } else if (event is ParticipantDisconnectedEvent) {
        _addSystemMessage("${event.participant.name} Left");
      }
      _safeNotify();
      _safeRoomUpdate();
    } else if (event is RoomDisconnectedEvent) {
      _addSystemMessage("Classroom connection ended");
      _safeNotify();
      _safeRoomUpdate();
    } else if (event is RoomReconnectedEvent) {
      _addSystemMessage("Reconnected to live classroom");
      _safeNotify();
      _safeRoomUpdate();
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
            _reactionStreamController.add({'userId': decoded['userId'], 'emoji': decoded['emoji']});
          }
        } else if (type == 'role_assigned') {
          final uId = decoded['userId'] as String?;
          final newRole = decoded['newRole'] as String?;
          if (uId != null && newRole != null) {
            _customRoles[uId] = newRole;
            if (uId == currentUserId) {
              currentUserRole = newRole.toLowerCase();
            }
            _addSystemMessage("Participant role updated: $newRole");
            _safeNotify();
            _safeRoomUpdate();
          }
        }
      } catch (_) {}
    }
  }

  bool _isDisposed = false;
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

  Future<void> leaveRoom() async {
    _heartbeatTimer?.cancel();
    try {
      final apiService = ApiService();
      if (currentUserRole == 'teacher' || currentUserRole == 'admin') {
        await apiService.post('/live-classes/$liveClassId/end', {});
      } else {
        await apiService.post('/live-classes/$liveClassId/event', {
          'action': 'leave',
          'user_id': currentUserId,
        });
      }
    } catch (_) {}

    // Explicitly release all media stream hardware before disconnecting
    final localParticipant = _room?.localParticipant;
    if (localParticipant != null) {
      for (final pub in localParticipant.videoTrackPublications) {
        try {
          await pub.track?.stop();
          await pub.track?.dispose();
        } catch (_) {}
      }
      for (final pub in localParticipant.audioTrackPublications) {
        try {
          await pub.track?.stop();
          await pub.track?.dispose();
        } catch (_) {}
      }
    }

    if (_room != null) {
      await _room!.disconnect();
      _room = null;
    }
    _safeNotify();
    _safeRoomUpdate();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _heartbeatTimer?.cancel();
    final localParticipant = _room?.localParticipant;
    if (localParticipant != null) {
      for (final pub in localParticipant.videoTrackPublications) {
        try {
          pub.track?.stop();
          pub.track?.dispose();
        } catch (_) {}
      }
      for (final pub in localParticipant.audioTrackPublications) {
        try {
          pub.track?.stop();
          pub.track?.dispose();
        } catch (_) {}
      }
    }
    _room?.disconnect().catchError((_) {});
    _room = null;
    if (!_reactionStreamController.isClosed) _reactionStreamController.close();
    if (!_controlStreamController.isClosed) _controlStreamController.close();
    if (!_roomUpdateController.isClosed) _roomUpdateController.close();
    super.dispose();
  }
}

final liveRoomServiceProvider = ChangeNotifierProvider<InAppLiveRoomService>((ref) {
  return InAppLiveRoomService();
});
