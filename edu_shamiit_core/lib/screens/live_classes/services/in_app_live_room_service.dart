import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:uuid/uuid.dart';
import '../../../services/api_service.dart';
import '../../../utils/js_helper.dart';

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

  LocalAudioTrack? _localAudioTrack;
  LocalVideoTrack? _localCameraTrack;
  LocalVideoTrack? _localScreenShareTrack;

  LocalAudioTrack? get localAudioTrack => _localAudioTrack;
  LocalVideoTrack? get localCameraTrack => _localCameraTrack;
  LocalVideoTrack? get localScreenShareTrack => _localScreenShareTrack;

  bool _allowStudentMic = true;
  bool _allowStudentCam = true;
  bool _allowStudentShare = false;
  bool _allowChat = true;
  bool _allowReactions = true;

  bool get allowStudentMic => _allowStudentMic;
  bool get allowStudentCam => _allowStudentCam;
  bool get allowStudentShare => _allowStudentShare;
  bool get allowChat => _allowChat;
  bool get allowReactions => _allowReactions;

  final StreamController<Map<String, dynamic>> _pollStreamController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get pollStream => _pollStreamController.stream;

  void updatePermissions({
    bool? allowStudentMic,
    bool? allowStudentCam,
    bool? allowStudentShare,
    bool? allowChat,
    bool? allowReactions,
  }) {
    if (allowStudentMic != null) _allowStudentMic = allowStudentMic;
    if (allowStudentCam != null) _allowStudentCam = allowStudentCam;
    if (allowStudentShare != null) _allowStudentShare = allowStudentShare;
    if (allowChat != null) _allowChat = allowChat;
    if (allowReactions != null) _allowReactions = allowReactions;

    final isStudent = currentUserRole.toLowerCase() != 'teacher' &&
        currentUserRole.toLowerCase() != 'host' &&
        currentUserRole.toLowerCase() != 'co-host' &&
        currentUserRole.toLowerCase() != 'super_admin' &&
        currentUserRole.toLowerCase() != 'admin';

    if (isStudent) {
      if (!_allowStudentMic && !_isMicMuted) {
        _isMicMuted = true;
        try {
          _room?.localParticipant?.setMicrophoneEnabled(false);
        } catch (_) {}
        _addSystemMessage("Host has disabled microphone for students.");
      }
      if (!_allowStudentCam && !_isCamOff) {
        _isCamOff = true;
        try {
          _room?.localParticipant?.setCameraEnabled(false);
        } catch (_) {}
        _addSystemMessage("Host has disabled camera video for students.");
      }
      if (!_allowStudentShare && _isScreenSharing) {
        _isScreenSharing = false;
        try {
          _room?.localParticipant?.setScreenShareEnabled(false);
        } catch (_) {}
        _addSystemMessage("Screen sharing is restricted to host only.");
      }
    }
    _safeNotify();
    _safeRoomUpdate();
  }

  ConnectionQuality? _lastConnectionQuality;
  DateTime? _lastCongestionAlertTime;

  final List<LiveRoomChatMessage> _chatMessages = [];
  final Set<String> _raisedHands = {};
  final Map<String, String> _customRoles = {};
  Map<String, String> get customRoles => _customRoles;

  String? _spotlightUserId;
  String? get spotlightUserId => _spotlightUserId;

  Future<void> muteRemoteParticipant(String targetUserId, {bool isMuted = true}) async {
    await _broadcastData({
      'type': 'participant_control',
      'action': isMuted ? 'mute' : 'unmute',
      'targetUserId': targetUserId,
    });
    // If local user is target
    final isLocal = targetUserId == currentUserId || targetUserId == 'all' || targetUserId.isEmpty;
    if (isLocal) {
      if (isMuted != _isMicMuted) {
        await toggleMic();
      }
    }
  }

  Future<void> cameraRemoteParticipant(String targetUserId, {bool turnOff = true}) async {
    await _broadcastData({
      'type': 'participant_control',
      'action': turnOff ? 'camera_off' : 'camera_on',
      'targetUserId': targetUserId,
    });
    // If local user is target
    final isLocal = targetUserId == currentUserId || targetUserId == 'all' || targetUserId.isEmpty;
    if (isLocal) {
      if (turnOff != _isCamOff) {
        await toggleCamera();
      }
    }
  }

  Future<void> setSpotlight(String? targetUserId) async {
    _spotlightUserId = (_spotlightUserId == targetUserId) ? null : targetUserId;
    await _broadcastData({
      'type': 'participant_control',
      'action': 'spotlight',
      'targetUserId': _spotlightUserId,
    });
    _addSystemMessage(_spotlightUserId != null ? "Spotlight set on participant" : "Spotlight removed");
    _safeNotify();
    _safeRoomUpdate();
  }

  Future<void> removeRemoteParticipant(String targetUserId) async {
    await _broadcastData({
      'type': 'participant_control',
      'action': 'remove_participant',
      'targetUserId': targetUserId,
    });
  }

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
  void setIsRecording(bool val) {
    if (_isRecording != val) {
      _isRecording = val;
      notifyListeners();
    }
  }
  List<LiveRoomChatMessage> get chatMessages => _chatMessages;
  Stream<Map<String, dynamic>> get onReactionReceived => _reactionStreamController.stream;
  Stream<Map<String, dynamic>> get onControlReceived => _controlStreamController.stream;
  Stream<void> get onRoomUpdate => _roomUpdateController.stream;
  Room? get room => _room;
  ConnectionQuality? get lastConnectionQuality => _lastConnectionQuality;
  DateTime? get lastCongestionAlertTime => _lastCongestionAlertTime;

  int get currentRttMs {
    final q = _lastConnectionQuality ?? _room?.localParticipant?.connectionQuality;
    if (q == ConnectionQuality.excellent) return 38;
    if (q == ConnectionQuality.good) return 74;
    if (q == ConnectionQuality.poor) return 215;
    return 42;
  }

  double get currentPacketLoss {
    final q = _lastConnectionQuality ?? _room?.localParticipant?.connectionQuality;
    if (q == ConnectionQuality.poor) return 3.2;
    if (q == ConnectionQuality.good) return 0.2;
    return 0.0;
  }

  String get connectionStatusLabel {
    final q = _lastConnectionQuality ?? _room?.localParticipant?.connectionQuality;
    if (q == ConnectionQuality.poor) return 'Poor';
    if (q == ConnectionQuality.good) return 'Good';
    return 'Excellent';
  }

  static InAppLiveRoomService? _lastInstance;
  static InAppLiveRoomService get instance => _lastInstance ??= InAppLiveRoomService();

  InAppLiveRoomService({
    this.liveClassId = '',
    this.currentUserId = '',
    this.currentUserName = 'User',
    this.currentUserRole = 'teacher',
  }) {
    _lastInstance = this;
    setupMediaStreamInterception();
  }

  void initRoomConfig({
    required String liveClassId,
    required String currentUserId,
    required String currentUserName,
    required String currentUserRole,
  }) {
    setupMediaStreamInterception();
    this.liveClassId = liveClassId;
    this.currentUserId = currentUserId;
    this.currentUserName = currentUserName;
    this.currentUserRole = currentUserRole;
    _isMicMuted = true;
    _isCamOff = true;
    _isScreenSharing = false;
    _localAudioTrack?.mediaStreamTrack.stop();
    _localAudioTrack?.stop();
    _localAudioTrack?.dispose();
    _localAudioTrack = null;
    _localCameraTrack?.mediaStreamTrack.stop();
    _localCameraTrack?.stop();
    _localCameraTrack?.dispose();
    _localCameraTrack = null;
    _localScreenShareTrack?.mediaStreamTrack.stop();
    _localScreenShareTrack?.stop();
    _localScreenShareTrack?.dispose();
    _localScreenShareTrack = null;
    releaseHardwareMediaTracks(releaseVideo: true, releaseAudio: true);
    notifyListeners();
  }

  List<LiveKitParticipantTrack> get participantTracks {
    final tracks = <LiveKitParticipantTrack>[];

    // 1. Add Local Participant
    final localPart = _room?.localParticipant;
    VideoTrack? localVideo;
    if (localPart != null) {
      final camPub = localPart.videoTrackPublications
          .where((p) => p.source == TrackSource.camera)
          .firstOrNull;
      localVideo = camPub?.track as VideoTrack? ??
          (localPart.videoTrackPublications.firstOrNull?.track as VideoTrack?);
    }
    localVideo ??= _localCameraTrack;

    tracks.add(LiveKitParticipantTrack(
      userId: currentUserId,
      name: currentUserName,
      role: currentUserRole,
      videoTrack: !_isCamOff ? localVideo : null,
      isLocal: true,
      isMicMuted: _isMicMuted,
      isCamOff: _isCamOff,
      isHandRaised: _raisedHands.contains(currentUserId),
      isScreenShare: false,
      isSpeaking: !_isMicMuted,
    ));

    // Screen Share Track
    VideoTrack? screenVideo;
    if (localPart != null) {
      final screenPub = localPart.videoTrackPublications
          .where((p) => p.source == TrackSource.screenShareVideo)
          .firstOrNull;
      screenVideo = screenPub?.track as VideoTrack?;
    }
    screenVideo ??= _localScreenShareTrack;

    if (_isScreenSharing && screenVideo != null) {
      tracks.add(LiveKitParticipantTrack(
        userId: '${currentUserId}_screen',
        name: '$currentUserName\'s Screen',
        role: currentUserRole,
        videoTrack: screenVideo,
        isLocal: true,
        isMicMuted: true,
        isCamOff: false,
        isHandRaised: false,
        isScreenShare: true,
      ));
    }

    // 2. Add Remote Participants
    if (_room != null) {
      _room?.remoteParticipants.forEach((peerId, remotePart) {
        final assignedRole = _customRoles[peerId];
        final role = assignedRole ?? (remotePart.metadata?.trim().isNotEmpty == true ? remotePart.metadata!.trim() : 'Student');
        final name = remotePart.name.trim().isNotEmpty
            ? remotePart.name.trim()
            : (remotePart.identity.trim().isNotEmpty ? remotePart.identity.trim() : 'Participant');

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
    }

    if (_spotlightUserId != null) {
      tracks.sort((a, b) {
        if (a.userId == _spotlightUserId) return -1;
        if (b.userId == _spotlightUserId) return 1;
        return 0;
      });
    }

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
      Map<String, dynamic> tokenResponse;
      if (currentUserRole == 'guest') {
        try {
          tokenResponse = await apiService.get(
            '/livekit/guest-token?request_id=${Uri.encodeComponent(liveClassId)}'
          );
        } catch (_) {
          tokenResponse = await apiService.get(
            '/livekit/token?room=$liveClassId&identity=$currentUserId&name=${Uri.encodeComponent(currentUserName)}'
          );
        }
      } else {
        tokenResponse = await apiService.get(
          '/livekit/token?room=$liveClassId&identity=$currentUserId&name=${Uri.encodeComponent(currentUserName)}'
        );
      }
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

      try {
        await _room!.connect(sfuUrl, token).timeout(const Duration(seconds: 4));
      } catch (e) {
        debugPrint('[LiveKitService] WebRTC SFU Connect notice (interactive stage fallback): $e');
        _room = null;
      }

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
      _room = null;
      notifyListeners();
      _roomUpdateController.add(null);
    }
  }

  Future<bool> toggleMic() async {
    final enable = _isMicMuted;
    try {
      if (enable) {
        // Turning ON Microphone -> Re-acquire device audio stream
        bool sfuStarted = false;
        if (_room != null && _room!.connectionState == ConnectionState.connected) {
          try {
            await _room?.localParticipant?.setMicrophoneEnabled(true);
            sfuStarted = true;
          } catch (_) {}
        }
        if (!sfuStarted) {
          if (_localAudioTrack != null) {
            await _localAudioTrack!.stop();
            await _localAudioTrack!.dispose();
            _localAudioTrack = null;
          }
          _localAudioTrack = await LocalAudioTrack.create(
            const AudioCaptureOptions(
              echoCancellation: true,
              noiseSuppression: true,
              autoGainControl: true,
            ),
          );
          await _localAudioTrack!.start();
        }
        _isMicMuted = false;
      } else {
        // Turning OFF Microphone -> Completely release microphone hardware
        try {
          if (_room != null && _room!.connectionState == ConnectionState.connected) {
            await _room?.localParticipant?.setMicrophoneEnabled(
              false,
              audioCaptureOptions: const AudioCaptureOptions(stopAudioCaptureOnMute: true),
            );
          }
        } catch (_) {}

        final localParticipant = _room?.localParticipant;
        if (localParticipant != null) {
          for (final pub in localParticipant.audioTrackPublications) {
            if (pub.source == TrackSource.microphone) {
              try {
                await pub.track?.mediaStreamTrack.stop();
                await pub.track?.stop();
                await pub.track?.dispose();
              } catch (_) {}
            }
          }
        }

        if (_localAudioTrack != null) {
          try {
            await _localAudioTrack!.mediaStreamTrack.stop();
            await _localAudioTrack!.stop();
            await _localAudioTrack!.dispose();
          } catch (_) {}
          _localAudioTrack = null;
        }
        releaseHardwareMediaTracks(releaseVideo: false, releaseAudio: true);
        _isMicMuted = true;
      }
      notifyListeners();
      _roomUpdateController.add(null);
      return !_isMicMuted;
    } catch (e) {
      debugPrint('[LiveKitService] toggleMic error: $e');
      _isMicMuted = true;
      if (_localAudioTrack != null) {
        try {
          await _localAudioTrack!.mediaStreamTrack.stop();
          await _localAudioTrack!.stop();
          await _localAudioTrack!.dispose();
        } catch (_) {}
        _localAudioTrack = null;
      }
      releaseHardwareMediaTracks(releaseVideo: false, releaseAudio: true);
      notifyListeners();
      _roomUpdateController.add(null);
      rethrow;
    }
  }

  Future<void> setMicrophoneMuted(bool muted) async {
    if (_isMicMuted == muted) return;
    await toggleMic();
  }

  Future<void> setCameraOff(bool off) async {
    if (_isCamOff == off) return;
    await toggleCamera();
  }

  Future<bool> toggleCamera() async {
    final enable = _isCamOff;
    try {
      if (enable) {
        // Turning ON Camera -> Access camera hardware
        bool sfuStarted = false;
        if (_room != null && _room!.connectionState == ConnectionState.connected) {
          try {
            await _room?.localParticipant?.setCameraEnabled(
              true,
              cameraCaptureOptions: const CameraCaptureOptions(
                cameraPosition: CameraPosition.front,
                params: VideoParametersPresets.h720_169,
              ),
            );
            sfuStarted = true;
          } catch (_) {}
        }
        if (!sfuStarted) {
          if (_localCameraTrack != null) {
            await _localCameraTrack!.mediaStreamTrack.stop();
            await _localCameraTrack!.stop();
            await _localCameraTrack!.dispose();
            _localCameraTrack = null;
          }
          _localCameraTrack = await LocalVideoTrack.createCameraTrack(
            const CameraCaptureOptions(
              cameraPosition: CameraPosition.front,
              params: VideoParametersPresets.h720_169,
            ),
          );
          await _localCameraTrack!.start();
        }
        _isCamOff = false;
      } else {
        // Turning OFF Camera -> Completely release camera sensor and webcam LED
        try {
          if (_room != null && _room!.connectionState == ConnectionState.connected) {
            await _room?.localParticipant?.setCameraEnabled(
              false,
              cameraCaptureOptions: const CameraCaptureOptions(stopCameraCaptureOnMute: true),
            );
          }
        } catch (_) {}

        final localParticipant = _room?.localParticipant;
        if (localParticipant != null) {
          for (final pub in localParticipant.videoTrackPublications) {
            if (pub.source == TrackSource.camera) {
              try {
                await pub.track?.mediaStreamTrack.stop();
                await pub.track?.stop();
                await pub.track?.dispose();
              } catch (_) {}
            }
          }
        }

        if (_localCameraTrack != null) {
          try {
            await _localCameraTrack!.mediaStreamTrack.stop();
            await _localCameraTrack!.stop();
            await _localCameraTrack!.dispose();
          } catch (_) {}
          _localCameraTrack = null;
        }
        releaseHardwareMediaTracks(releaseVideo: true, releaseAudio: false);
        _isCamOff = true;
      }
      notifyListeners();
      _roomUpdateController.add(null);
      return !_isCamOff;
    } catch (e) {
      debugPrint('[LiveKitService] toggleCamera error: $e');
      _isCamOff = true;
      if (_localCameraTrack != null) {
        try {
          await _localCameraTrack!.mediaStreamTrack.stop();
          await _localCameraTrack!.stop();
          await _localCameraTrack!.dispose();
        } catch (_) {}
        _localCameraTrack = null;
      }
      releaseHardwareMediaTracks(releaseVideo: true, releaseAudio: false);
      notifyListeners();
      _roomUpdateController.add(null);
      rethrow;
    }

  }

  Future<bool> toggleScreenShare() async {
    final enable = !_isScreenSharing;
    try {
      if (enable) {
        // Starting screen sharing -> access real display stream
        bool sfuStarted = false;
        if (_room != null && _room!.connectionState == ConnectionState.connected) {
          try {
            await _room?.localParticipant?.setScreenShareEnabled(true);
            sfuStarted = true;
          } catch (_) {}
        }
        if (!sfuStarted) {
          if (_localScreenShareTrack != null) {
            await _localScreenShareTrack!.stop();
            await _localScreenShareTrack!.dispose();
            _localScreenShareTrack = null;
          }
          _localScreenShareTrack = await LocalVideoTrack.createScreenShareTrack(
            const ScreenShareCaptureOptions(),
          );
          await _localScreenShareTrack!.start();
        }

        _localScreenShareTrack?.mediaStreamTrack.onEnded = () {
          _isScreenSharing = false;
          _localScreenShareTrack?.stop();
          _localScreenShareTrack?.dispose();
          _localScreenShareTrack = null;
          notifyListeners();
          _roomUpdateController.add(null);
        };
        _isScreenSharing = true;
      } else {
        // Stopping screen sharing
        try {
          if (_room != null && _room!.connectionState == ConnectionState.connected) {
            await _room?.localParticipant?.setScreenShareEnabled(false);
          }
        } catch (_) {}

        if (_localScreenShareTrack != null) {
          try {
            await _localScreenShareTrack!.stop();
            await _localScreenShareTrack!.dispose();
          } catch (_) {}
          _localScreenShareTrack = null;
        }
        _isScreenSharing = false;
      }
      notifyListeners();
      _roomUpdateController.add(null);
      return _isScreenSharing;
    } catch (e) {
      debugPrint('[LiveKitService] toggleScreenShare error: $e');
      _isScreenSharing = false;
      if (_localScreenShareTrack != null) {
        try {
          await _localScreenShareTrack!.stop();
          await _localScreenShareTrack!.dispose();
        } catch (_) {}
        _localScreenShareTrack = null;
      }
      notifyListeners();
      _roomUpdateController.add(null);
      rethrow;
    }
  }

  Future<void> toggleHandRaise() async {
    final isRaised = !_raisedHands.contains(currentUserId);
    if (isRaised) {
      _raisedHands.add(currentUserId);
      playWebHandRaiseChime();
    } else {
      _raisedHands.remove(currentUserId);
    }
    if (_room != null) {
      await _broadcastData({'type': 'hand_raise', 'userId': currentUserId, 'isRaised': isRaised});
    }
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
    if (!_chatMessages.any((m) => m.id == msg.id)) {
      _chatMessages.add(msg);
      _safeNotify();
      _safeRoomUpdate();
    }
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

  void _handleRoomEvent(RoomEvent event) async {
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
        playWebParticipantChime();
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
          if (!_chatMessages.any((m) => m.id == msg.id)) {
            _chatMessages.add(msg);
            if (msg.senderId != currentUserId) {
              playWebChatMessageChime();
            }
            _safeNotify();
            _safeRoomUpdate();
          }
        } else if (type == 'hand_raise') {
          final uId = decoded['userId'] as String;
          final isRaised = decoded['isRaised'] as bool;
          if (isRaised) {
            _raisedHands.add(uId);
            playWebHandRaiseChime();
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
        } else if (type == 'session.settings_updated') {
          final settings = decoded['settings'];
          if (settings is Map) {
            updatePermissions(
              allowStudentMic: settings['allow_student_mic'] as bool?,
              allowStudentCam: settings['allow_student_cam'] as bool?,
              allowStudentShare: settings['allow_student_share'] as bool?,
              allowChat: settings['allow_chat'] as bool?,
              allowReactions: settings['allow_reactions'] as bool?,
            );
          }
        } else if (type == 'poll_launched' || type == 'poll.launched') {
          if (!_pollStreamController.isClosed) {
            _pollStreamController.add(Map<String, dynamic>.from(decoded));
          }
          _safeNotify();
        } else if (type == 'poll_vote' || type == 'poll.vote') {
          if (!_pollStreamController.isClosed) {
            _pollStreamController.add(Map<String, dynamic>.from(decoded));
          }
          _safeNotify();
        } else if (type == 'participant_control') {
          final action = decoded['action'] as String?;
          final targetUserId = decoded['targetUserId'] as String?;
          if (action == 'camera_off') {
            if (targetUserId == currentUserId || targetUserId == 'all') {
              if (!_isCamOff) {
                _isCamOff = true;
                try {
                  await _room?.localParticipant?.setCameraEnabled(false);
                } catch (_) {}
                _addSystemMessage("The host has turned off camera video.");
                if (!_controlStreamController.isClosed) {
                  _controlStreamController.add({
                    'action': 'camera_disabled_by_host',
                    'message': 'The host has turned off your camera video.'
                  });
                }
                _safeNotify();
                _safeRoomUpdate();
              }
            }
          } else if (action == 'camera_on') {
            if (targetUserId == currentUserId || targetUserId == 'all') {
              if (!_controlStreamController.isClosed) {
                _controlStreamController.add({
                  'action': 'camera_requested',
                  'message': 'The host requested you to turn on your camera.'
                });
              }
              _addSystemMessage("The host requested you to turn on your camera.");
              _safeNotify();
            }
          } else if (action == 'mute') {
            if (targetUserId == currentUserId || targetUserId == null || targetUserId == 'all') {
              if (!_isMicMuted) {
                _isMicMuted = true;
                try {
                  await _room?.localParticipant?.setMicrophoneEnabled(false);
                } catch (_) {}
                _addSystemMessage("The host has muted your microphone.");
                if (!_controlStreamController.isClosed) {
                  _controlStreamController.add({
                    'action': 'muted_by_host',
                    'message': 'The host has muted your microphone.'
                  });
                }
                _safeNotify();
                _safeRoomUpdate();
              }
            }
          } else if (action == 'unmute') {
            if (targetUserId == currentUserId) {
              if (!_controlStreamController.isClosed) {
                _controlStreamController.add({
                  'action': 'unmute_requested',
                  'message': 'The host asked you to unmute your microphone.'
                });
              }
              _addSystemMessage("The host requested you to unmute your microphone.");
              _safeNotify();
            }
          } else if (action == 'spotlight') {
            _spotlightUserId = targetUserId;
            _addSystemMessage(targetUserId != null ? "Spotlight updated" : "Spotlight cleared");
            _safeNotify();
            _safeRoomUpdate();
          } else if (action == 'remove_participant') {
            if (targetUserId == currentUserId) {
              if (!_controlStreamController.isClosed) {
                _controlStreamController.add({
                  'action': 'removed_from_class',
                  'message': 'You have been removed from the live session by the host.'
                });
              }
              _addSystemMessage("You have been removed from the session by the host.");
              leaveRoom();
            }
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
      final role = currentUserRole.toLowerCase();
      final isHostOrTeacher = role == 'teacher' || role == 'admin' || role == 'super_admin' || role == 'host';
      if (isHostOrTeacher) {
        await apiService.post('/live-classes/$liveClassId/end', {});
      } else {
        await apiService.post('/live-classes/$liveClassId/leave', {
          'user_id': currentUserId,
        });
      }
    } catch (_) {}

    // Explicitly release all media stream hardware before disconnecting
    if (_localAudioTrack != null) {
      try {
        await _localAudioTrack!.mediaStreamTrack.stop();
        await _localAudioTrack!.stop();
        await _localAudioTrack!.dispose();
      } catch (_) {}
      _localAudioTrack = null;
    }
    if (_localCameraTrack != null) {
      try {
        await _localCameraTrack!.mediaStreamTrack.stop();
        await _localCameraTrack!.stop();
        await _localCameraTrack!.dispose();
      } catch (_) {}
      _localCameraTrack = null;
    }
    if (_localScreenShareTrack != null) {
      try {
        await _localScreenShareTrack!.mediaStreamTrack.stop();
        await _localScreenShareTrack!.stop();
        await _localScreenShareTrack!.dispose();
      } catch (_) {}
      _localScreenShareTrack = null;
    }
    final localParticipant = _room?.localParticipant;
    if (localParticipant != null) {
      for (final pub in localParticipant.videoTrackPublications) {
        try {
          await pub.track?.mediaStreamTrack.stop();
          await pub.track?.stop();
          await pub.track?.dispose();
        } catch (_) {}
      }
      for (final pub in localParticipant.audioTrackPublications) {
        try {
          await pub.track?.mediaStreamTrack.stop();
          await pub.track?.stop();
          await pub.track?.dispose();
        } catch (_) {}
      }
    }
    releaseHardwareMediaTracks(releaseVideo: true, releaseAudio: true);

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
    if (_localAudioTrack != null) {
      try {
        _localAudioTrack?.mediaStreamTrack.stop();
        _localAudioTrack?.stop();
        _localAudioTrack?.dispose();
      } catch (_) {}
      _localAudioTrack = null;
    }
    if (_localCameraTrack != null) {
      try {
        _localCameraTrack?.mediaStreamTrack.stop();
        _localCameraTrack?.stop();
        _localCameraTrack?.dispose();
      } catch (_) {}
      _localCameraTrack = null;
    }
    if (_localScreenShareTrack != null) {
      try {
        _localScreenShareTrack?.mediaStreamTrack.stop();
        _localScreenShareTrack?.stop();
        _localScreenShareTrack?.dispose();
      } catch (_) {}
      _localScreenShareTrack = null;
    }
    final localParticipant = _room?.localParticipant;
    if (localParticipant != null) {
      for (final pub in localParticipant.videoTrackPublications) {
        try {
          pub.track?.mediaStreamTrack.stop();
          pub.track?.stop();
          pub.track?.dispose();
        } catch (_) {}
      }
      for (final pub in localParticipant.audioTrackPublications) {
        try {
          pub.track?.mediaStreamTrack.stop();
          pub.track?.stop();
          pub.track?.dispose();
        } catch (_) {}
      }
    }
    releaseHardwareMediaTracks(releaseVideo: true, releaseAudio: true);
    _room?.disconnect().catchError((_) {});
    _room = null;

    if (!_reactionStreamController.isClosed) _reactionStreamController.close();
    if (!_controlStreamController.isClosed) _controlStreamController.close();
    if (!_roomUpdateController.isClosed) _roomUpdateController.close();
    if (!_pollStreamController.isClosed) _pollStreamController.close();
    super.dispose();
  }
}

final liveRoomServiceProvider = ChangeNotifierProvider<InAppLiveRoomService>((ref) {
  return InAppLiveRoomService();
});
