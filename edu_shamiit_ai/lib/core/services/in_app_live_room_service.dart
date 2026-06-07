import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:uuid/uuid.dart';
import 'supabase_service.dart';
import 'api_service.dart';

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

  LiveKitParticipantTrack({
    required this.userId,
    required this.name,
    required this.role,
    this.videoTrack,
    required this.isLocal,
    required this.isMicMuted,
    required this.isCamOff,
    required this.isHandRaised,
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

  final List<LiveRoomChatMessage> _chatMessages = [];
  final Set<String> _raisedHands = {};
  
  // Streams for real-time reactions and host commands
  final _reactionStreamController = StreamController<Map<String, dynamic>>.broadcast();
  final _controlStreamController = StreamController<Map<String, dynamic>>.broadcast();
  final _roomUpdateController = StreamController<void>.broadcast();

  // Getters
  bool get isScreenSharing => _isScreenSharing;
  bool get isMicMuted => _isMicMuted;
  bool get isCamOff => _isCamOff;
  bool get isRecording => _isRecording;
  List<LiveRoomChatMessage> get chatMessages => _chatMessages;
  Stream<Map<String, dynamic>> get onReactionReceived => _reactionStreamController.stream;
  Stream<Map<String, dynamic>> get onControlReceived => _controlStreamController.stream;
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
      final localVideo = localPart.videoTrackPublications.firstOrNull?.track as VideoTrack?;
      tracks.add(LiveKitParticipantTrack(
        userId: currentUserId,
        name: currentUserName,
        role: currentUserRole,
        videoTrack: localVideo,
        isLocal: true,
        isMicMuted: _isMicMuted,
        isCamOff: _isCamOff,
        isHandRaised: _raisedHands.contains(currentUserId),
      ));
    }

    // 2. Add Remote Participants
    _room?.remoteParticipants.forEach((peerId, remotePart) {
      final role = remotePart.metadata ?? 'student';
      final name = remotePart.name;
      final video = remotePart.videoTrackPublications.firstOrNull?.track as VideoTrack?;
      final micMuted = !(remotePart.audioTrackPublications.firstOrNull?.subscribed ?? false) || 
                        (remotePart.audioTrackPublications.firstOrNull?.muted ?? true);
      final camOff = !(remotePart.videoTrackPublications.firstOrNull?.subscribed ?? false) || 
                      (remotePart.videoTrackPublications.firstOrNull?.muted ?? true);

      tracks.add(LiveKitParticipantTrack(
        userId: peerId,
        name: name,
        role: role,
        videoTrack: video,
        isLocal: false,
        isMicMuted: micMuted,
        isCamOff: camOff,
        isHandRaised: _raisedHands.contains(peerId),
      ));
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
          _isRecording = true;
        } catch (e) {
          debugPrint('[LiveKitService] Warning: Failed to start session on backend: $e');
        }
      } else {
        // Log student join log
        try {
          await apiService.post('/live-classes/$liveClassId/attendance/mark', {
            'action': 'join'
          });
        } catch (_) {}
      }

      // 2. Fetch JWT Join Token from backend
      final tokenResponse = await apiService.get(
        '/livekit/token?room=$liveClassId&identity=$currentUserId&name=$currentUserName'
      );
      final String token = tokenResponse['token'];
      final String sfuUrl = tokenResponse['livekit_url'] ?? 'http://localhost:7880';
      
      // Connect to LiveKit Room
      _room = Room();
      
      // Room Event Listeners
      final listener = _room!.createListener();
      listener.on<RoomEvent>((event) {
        _handleRoomEvent(event);
      });

      // Connect to room using LiveKit URL
      await _room!.connect(sfuUrl, token);
      
      // Enable camera and microphone automatically on join
      await _room?.localParticipant?.setMicrophoneEnabled(true);
      await _room?.localParticipant?.setCameraEnabled(true);

      // Load chat history from backend database
      try {
        final chatResponse = await apiService.get('/live-classes/$liveClassId/chat');
        final List chats = chatResponse['data']['chats'] ?? [];
        _chatMessages.clear();
        for (final c in chats) {
          _chatMessages.add(LiveRoomChatMessage.fromJson(c));
        }
      } catch (_) {}

      // System message: recording starts
      _addSystemMessage("Recording Started");

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
    await _room?.localParticipant?.setCameraEnabled(!_isCamOff);
    notifyListeners();
    _roomUpdateController.add(null);
  }

  /// Toggle Screen Sharing
  Future<void> toggleScreenShare() async {
    if (_room == null) return;
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
    await _broadcastData({
      'type': 'hand_raise',
      'userId': currentUserId,
      'isRaised': isRaised
    });

    notifyListeners();
    _roomUpdateController.add(null);
  }

  /// Send emoji reaction to all participants
  Future<void> sendReaction(String emoji) async {
    if (_room == null) return;
    
    // Broadcast emoji
    await _broadcastData({
      'type': 'reaction',
      'userId': currentUserId,
      'emoji': emoji
    });

    // Also trigger locally
    _reactionStreamController.add({
      'userId': currentUserId,
      'emoji': emoji
    });
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
      await apiService.post('/live-classes/$liveClassId/chat', {
        'message': text
      });
    } catch (_) {}

    // Broadcast message to LiveKit Room
    await _broadcastData({
      'type': 'chat',
      'message': message.toJson()
    });

    _chatMessages.add(message);
    notifyListeners();
    _roomUpdateController.add(null);
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
    await _broadcastData({
      'type': 'control',
      'targetUserId': targetUserId,
      'action': 'remove'
    });
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
    if (event is TrackSubscribedEvent || event is TrackUnsubscribedEvent || 
        event is ParticipantConnectedEvent || event is ParticipantDisconnectedEvent) {
      if (event is ParticipantConnectedEvent) {
        final pName = event.participant.name;
        _addSystemMessage("${pName.isEmpty ? 'Student' : pName} Joined");
      } else if (event is ParticipantDisconnectedEvent) {
        final pName = event.participant.name;
        _addSystemMessage("${pName.isEmpty ? 'Student' : pName} Left");
      }
      notifyListeners();
      _roomUpdateController.add(null);
    } else if (event is DataReceivedEvent) {
      try {
        final decoded = json.decode(utf8.decode(event.data));
        final type = decoded['type'] as String?;

        if (type == 'chat') {
          final msg = LiveRoomChatMessage.fromJson(decoded['message']);
          _chatMessages.add(msg);
          notifyListeners();
          _roomUpdateController.add(null);
        } else if (type == 'hand_raise') {
          final uId = decoded['userId'] as String;
          final isRaised = decoded['isRaised'] as bool;
          if (isRaised) {
            _raisedHands.add(uId);
          } else {
            _raisedHands.remove(uId);
          }
          notifyListeners();
          _roomUpdateController.add(null);
        } else if (type == 'reaction') {
          _reactionStreamController.add({
            'userId': decoded['userId'],
            'emoji': decoded['emoji']
          });
        } else if (type == 'control') {
          final target = decoded['targetUserId'] as String;
          final action = decoded['action'] as String;

          if (target == currentUserId) {
            _handleHostControlAction(action);
          }
        }
      } catch (e) {
        debugPrint('[LiveKitService] Error parsing data packet: $e');
      }
    }
  }

  /// Handle incoming administrative commands from host
  void _handleHostControlAction(String action) {
    if (action == 'mute_mic') {
      if (!_isMicMuted) toggleMic();
    } else if (action == 'disable_camera') {
      if (!_isCamOff) toggleCamera();
    } else if (action == 'remove') {
      _controlStreamController.add({'action': 'removed'});
      leaveRoom();
    }
  }

  /// Local system message adder
  void _addSystemMessage(String text) {
    _chatMessages.add(LiveRoomChatMessage(
      id: const Uuid().v4(),
      senderId: 'system',
      senderName: 'System',
      senderRole: 'system',
      text: text,
      time: DateTime.now(),
    ));
  }

  /// Leave call and clean up connection resources
  Future<void> leaveRoom() async {
    if (_room == null) return;
    try {
      final apiService = ApiService();

      if (currentUserRole == 'teacher') {
        _isRecording = false;
        try {
          await apiService.post('/live-classes/$liveClassId/end', {});
        } catch (_) {}
      } else {
        // Mark student leave log
        try {
          await apiService.post('/live-classes/$liveClassId/attendance/mark', {
            'action': 'leave'
          });
        } catch (_) {}
      }

      await _room!.disconnect();
      _room = null;
      _raisedHands.clear();
      _chatMessages.clear();
      
      notifyListeners();
      _roomUpdateController.add(null);
    } catch (e) {
      debugPrint('[LiveKitService] Error leaving room: $e');
    }
  }

  @override
  void dispose() {
    leaveRoom();
    _reactionStreamController.close();
    _controlStreamController.close();
    _roomUpdateController.close();
    super.dispose();
  }
}
