// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../utils/js_helper.dart';

// ============================================================================
// CALL STATE ENUMS
// ============================================================================
enum CallState { idle, ringing, connecting, active, ended }

enum CallType { audio, video }

// ============================================================================
// ACTIVE CALL INFO
// ============================================================================
class ActiveCallInfo {
  final String sessionId;
  final String peerId;
  final String peerName;
  final String? peerAvatarUrl;
  final CallType callType;
  final bool isOutgoing;
  CallState state;

  ActiveCallInfo({
    required this.sessionId,
    required this.peerId,
    required this.peerName,
    this.peerAvatarUrl,
    required this.callType,
    required this.isOutgoing,
    this.state = CallState.ringing,
  });
}

// ============================================================================
// INCOMING CALL INFO
// ============================================================================
class IncomingCallInfo {
  final String sessionId;
  final String callerId;
  final String callerName;
  final String? callerAvatarUrl;
  final CallType callType;
  final String channelName;
  final RTCSessionDescription offer;
  final bool isGroup;
  final String? groupName;

  const IncomingCallInfo({
    required this.sessionId,
    required this.callerId,
    required this.callerName,
    this.callerAvatarUrl,
    required this.callType,
    required this.channelName,
    required this.offer,
    this.isGroup = false,
    this.groupName,
  });
}

// ============================================================================
// CALL SERVICE — Production WebRTC + Supabase Realtime Signaling
// ============================================================================
class CallService {
  CallService._();
  static final CallService instance = CallService._();

  // State notifiers for UI binding
  final ValueNotifier<ActiveCallInfo?> activeCall = ValueNotifier(null);
  final ValueNotifier<IncomingCallInfo?> incomingCall = ValueNotifier(null);

  // WebRTC objects
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;
  MediaStream? _screenStream;

  // Supabase Realtime signaling channel for the active call
  RealtimeChannel? _signalingChannel;
  String? _currentSignalingChannelName;

  // Global listener channel (always active when user is logged in)
  RealtimeChannel? _globalIncomingChannel;
  int _globalReconnectAttempts = 0;
  Timer? _globalReconnectTimer;

  // ICE config returned from backend
  Map<String, dynamic> _iceConfig = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ]
  };

  // Pending ICE candidates (to flush after remote description is set)
  final List<RTCIceCandidate> _pendingIceCandidates = [];

  // Remote video renderer (managed externally by CallScreen)
  RTCVideoRenderer? remoteRenderer;
  RTCVideoRenderer? localRenderer;

  // Callbacks (set by CallScreen widget)
  VoidCallback? onCallStateChanged;
  void Function(MediaStream)? onLocalStream;
  void Function(MediaStream)? onRemoteStream;
  void Function(bool isScreenSharing)? onScreenShareChanged;

  bool _isScreenSharing = false;
  bool get isScreenSharing => _isScreenSharing;

  bool _isMuted = false;
  bool get isMuted => _isMuted;

  bool _isCameraOff = false;
  bool get isCameraOff => _isCameraOff;

  final bool _isSpeakerOn = true;
  bool get isSpeakerOn => _isSpeakerOn;

  String _fastApiBaseUrl = AppConfig.baseUrl;
  String _currentUserId = '';

  String _channelName(String sessionId) => 'call_signal_$sessionId';

  // ─────────────────────────────────────────────────────────────────────────
  // INITIALIZE / DISPOSE
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> initialize(String currentUserId, String fastApiBaseUrl) async {
    if (currentUserId.isEmpty) return;
    if (_currentUserId == currentUserId && _globalIncomingChannel != null) {
      debugPrint('[CallService] Already initialized for user $currentUserId. Skipping duplicate initialization.');
      return;
    }
    _fastApiBaseUrl = fastApiBaseUrl.isNotEmpty ? fastApiBaseUrl : AppConfig.baseUrl;
    _currentUserId = currentUserId;
    await _setupGlobalIncomingListener(currentUserId);
    debugPrint('[CallService] Initialized for user $currentUserId at $_fastApiBaseUrl');
  }

  void dispose() {
    _globalReconnectTimer?.cancel();
    _globalReconnectTimer = null;
    _teardownSignaling();
    if (_globalIncomingChannel != null) {
      try {
        _globalIncomingChannel!.unsubscribe();
      } catch (_) {}
      _globalIncomingChannel = null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // OUTGOING CALL
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> initiateCall({
    required String calleeId,
    required String calleeName,
    String? calleeAvatarUrl,
    required CallType callType,
    bool isGroup = false,
    List<String> groupMemberIds = const [],
    String? groupName,
  }) async {
    if (activeCall.value != null) {
      debugPrint('[CallService] Already in a call, rejecting new call initiation');
      return;
    }

    try {
      if (kIsWeb) {
        if (hasMediaDevices() == false) {
          throw Exception(
              'Camera/Microphone access is blocked because this page is not served over a secure connection (HTTPS or localhost).\n\nTo allow calls on this device:\n1. Open chrome://flags/#unsafely-treat-insecure-origin-as-secure in Chrome.\n2. Enable the flag and add the current website URL to the list.\n3. Relaunch your browser.');
        }
      }

      // 1. Create backend session & get ICE credentials
      String sessionId;
      try {
        final sessionData = await _createCallSession(calleeId, callType);
        sessionId = sessionData['session_id'] as String;
        if (sessionData['ice_config'] is Map<String, dynamic>) {
          _iceConfig = sessionData['ice_config'] as Map<String, dynamic>;
        }
      } catch (e) {
        debugPrint('[CallService] Backend initiate call failed, falling back to direct signaling: $e');
        final cleanId = _currentUserId.isNotEmpty ? _currentUserId.substring(0, min(8, _currentUserId.length)) : 'anon';
        sessionId = 'call_${DateTime.now().millisecondsSinceEpoch}_$cleanId';
      }

      // 2. Create active call info
      activeCall.value = ActiveCallInfo(
        sessionId: sessionId,
        peerId: calleeId,
        peerName: isGroup ? (groupName ?? calleeName) : calleeName,
        peerAvatarUrl: calleeAvatarUrl,
        callType: callType,
        isOutgoing: true,
        state: CallState.ringing,
      );

      // 3. Subscribe to signaling channel
      final channelName = _channelName(sessionId);
      await _subscribeSignalingChannel(channelName);

      // 4. Capture local media (Camera & Mic or Mic only)
      _localStream = await _getUserMedia(callType);
      onLocalStream?.call(_localStream!);

      // 5. Create PeerConnection
      await _createPeerConnection();

      // 6. Add local tracks
      for (final track in _localStream!.getTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }

      // 7. Create and broadcast SDP offer
      final offer = await _peerConnection!.createOffer();
      await _peerConnection!.setLocalDescription(offer);

      _broadcastSignal(channelName, {
        'type': 'call_offer',
        'caller_id': _currentUserId,
        'caller_name': await _getCurrentUserName(),
        'caller_avatar': await _getCurrentUserAvatar(),
        'callee_id': calleeId,
        'call_type': callType.name,
        'session_id': sessionId,
        'sdp': offer.toMap(),
        'is_group': isGroup,
        'group_name': groupName,
        'group_member_ids': groupMemberIds,
      });

      onCallStateChanged?.call();
      debugPrint('[CallService] Call offer sent to $calleeName, waiting for answer...');
    } catch (e) {
      debugPrint('[CallService] Error initiating call: $e');
      if (kIsWeb) {
        String errMsg = e.toString();
        if (errMsg.contains('navigator.mediaDevices') ||
            errMsg.contains('undefined') ||
            errMsg.contains('Permission')) {
          errMsg =
              'Camera/Microphone access is blocked because this page is not served over a secure connection (HTTPS or localhost).\n\nTo allow calls on this device:\n1. Open chrome://flags/#unsafely-treat-insecure-origin-as-secure in Chrome.\n2. Enable the flag and add the current website URL to the list.\n3. Relaunch your browser.';
        }
        jsAlert(errMsg.replaceAll('Exception: ', ''));
      }
      await _endCallLocally();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ANSWER INCOMING CALL
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> answerCall(IncomingCallInfo incoming) async {
    _stopRingtone();
    incomingCall.value = null;
    final channelName = incoming.channelName;

    try {
      if (kIsWeb) {
        if (hasMediaDevices() == false) {
          throw Exception(
              'Camera/Microphone access is blocked because this page is not served over a secure connection (HTTPS or localhost).\n\nTo allow calls on this device:\n1. Open chrome://flags/#unsafely-treat-insecure-origin-as-secure in Chrome.\n2. Enable the flag and add the current website URL to the list.\n3. Relaunch your browser.');
        }
      }

      // 1. Fetch fresh ICE config if available
      final iceConfig = await _fetchIceConfig();
      if (iceConfig != null) _iceConfig = iceConfig;

      // 2. Set up active call
      activeCall.value = ActiveCallInfo(
        sessionId: incoming.sessionId,
        peerId: incoming.callerId,
        peerName: incoming.callerName,
        peerAvatarUrl: incoming.callerAvatarUrl,
        callType: incoming.callType,
        isOutgoing: false,
        state: CallState.connecting,
      );

      // 3. Subscribe to signaling channel
      await _subscribeSignalingChannel(channelName);

      // 4. Capture local media (Camera & Mic or Mic only)
      _localStream = await _getUserMedia(incoming.callType);
      onLocalStream?.call(_localStream!);

      // 5. Create PeerConnection
      await _createPeerConnection();

      // 6. Add local tracks
      for (final track in _localStream!.getTracks()) {
        await _peerConnection!.addTrack(track, _localStream!);
      }

      // 7. Set remote description (the offer)
      await _peerConnection!.setRemoteDescription(incoming.offer);
      await _flushPendingIceCandidates();

      // 8. Create and broadcast SDP answer
      final answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      _broadcastSignal(channelName, {
        'type': 'call_answer',
        'callee_id': _currentUserId,
        'caller_id': incoming.callerId,
        'sdp': answer.toMap(),
      });

      onCallStateChanged?.call();
      debugPrint('[CallService] Answer sent to ${incoming.callerName}');
    } catch (e) {
      debugPrint('[CallService] Error answering call: $e');
      if (kIsWeb) {
        String errMsg = e.toString();
        if (errMsg.contains('navigator.mediaDevices') ||
            errMsg.contains('undefined') ||
            errMsg.contains('Permission')) {
          errMsg =
              'Camera/Microphone access is blocked because this page is not served over a secure connection (HTTPS or localhost).\n\nTo allow calls on this device:\n1. Open chrome://flags/#unsafely-treat-insecure-origin-as-secure in Chrome.\n2. Enable the flag and add the current website URL to the list.\n3. Relaunch your browser.';
        }
        jsAlert(errMsg.replaceAll('Exception: ', ''));
      }
      await _endCallLocally();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // REJECT INCOMING CALL
  // ─────────────────────────────────────────────────────────────────────────
  void rejectIncomingCall() {
    _stopRingtone();
    final incoming = incomingCall.value;
    if (incoming == null) return;

    _broadcastSignal(incoming.channelName, {
      'type': 'call_rejected',
      'callee_id': _currentUserId,
      'caller_id': incoming.callerId,
    });

    if (incoming.sessionId.isNotEmpty) {
      _updateCallStatus(incoming.sessionId, 'rejected').catchError((e) {
        debugPrint('[CallService] Error updating call status to rejected: $e');
      });
    }

    incomingCall.value = null;
    _endCallLocally();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HANG UP
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> hangUp() async {
    final call = activeCall.value;
    if (call == null) return;

    // Signal hangup to peer
    final channelName = _channelName(call.sessionId);
    _broadcastSignal(channelName, {
      'type': 'call_hangup',
      'sender_id': _currentUserId,
    });

    // Update backend status
    if (!call.sessionId.startsWith('call_') && !call.sessionId.startsWith('incoming_')) {
      try {
        await _updateCallStatus(call.sessionId, 'ended');
      } catch (e) {
        debugPrint('[CallService] Error updating call status: $e');
      }
    }

    await _endCallLocally();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MEDIA CONTROLS
  // ─────────────────────────────────────────────────────────────────────────
  void toggleMute() {
    if (_localStream == null) return;
    _isMuted = !_isMuted;
    for (final track in _localStream!.getAudioTracks()) {
      track.enabled = !_isMuted;
    }
    onCallStateChanged?.call();
  }

  Future<void> toggleCamera() async {
    if (_localStream == null) return;
    _isCameraOff = !_isCameraOff;

    if (_isCameraOff) {
      for (final track in _localStream!.getVideoTracks()) {
        try {
          track.enabled = false;
          await track.stop();
        } catch (e) {
          debugPrint('[CallService] Error stopping camera track: $e');
        }
        _localStream!.removeTrack(track);
      }
    } else {
      if (_isScreenSharing) {
        await stopScreenShare();
      }

      try {
        final constraints = <String, dynamic>{
          'audio': false,
          'video': {
            'facingMode': 'user',
            'width': {'ideal': 1280},
            'height': {'ideal': 720},
          },
        };
        final newStream = await navigator.mediaDevices.getUserMedia(constraints);
        final videoTrack = newStream.getVideoTracks().firstOrNull;

        if (videoTrack != null) {
          await _localStream!.addTrack(videoTrack);

          if (_peerConnection != null) {
            final senders = await _peerConnection!.getSenders();
            for (final sender in senders) {
              if (sender.track?.kind == 'video') {
                await sender.replaceTrack(videoTrack);
              }
            }
          }
        }
      } catch (e) {
        debugPrint('[CallService] Error re-enabling camera: $e');
        _isCameraOff = true;
      }
    }

    onCallStateChanged?.call();
  }

  Future<void> switchCamera() async {
    if (_localStream == null) return;
    for (final track in _localStream!.getVideoTracks()) {
      await Helper.switchCamera(track);
    }
  }

  Future<void> startScreenShare() async {
    if (_isScreenSharing) return;
    try {
      _screenStream = await navigator.mediaDevices.getDisplayMedia({
        'video': true,
        'audio': false,
      });

      if (_peerConnection != null && _screenStream != null) {
        final videoTrack = _screenStream!.getVideoTracks().first;
        final senders = await _peerConnection!.getSenders();
        for (final sender in senders) {
          if (sender.track?.kind == 'video') {
            await sender.replaceTrack(videoTrack);
            break;
          }
        }
      }

      _isScreenSharing = true;
      onScreenShareChanged?.call(true);
      onCallStateChanged?.call();
      debugPrint('[CallService] Screen sharing started');
    } catch (e) {
      debugPrint('[CallService] Screen share error: $e');
    }
  }

  Future<void> stopScreenShare() async {
    if (!_isScreenSharing || _localStream == null) return;
    try {
      _screenStream?.getTracks().forEach((t) => t.stop());
      _screenStream = null;

      final videoTrack = _localStream!.getVideoTracks().firstOrNull;
      if (videoTrack != null && _peerConnection != null) {
        final senders = await _peerConnection!.getSenders();
        for (final sender in senders) {
          if (sender.track?.kind == 'video') {
            await sender.replaceTrack(videoTrack);
            break;
          }
        }
      }
      _isScreenSharing = false;
      onScreenShareChanged?.call(false);
      onCallStateChanged?.call();
    } catch (e) {
      debugPrint('[CallService] Stop screen share error: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GLOBAL INCOMING LISTENER (Supabase Realtime)
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _setupGlobalIncomingListener(String userId) async {
    _globalReconnectTimer?.cancel();
    if (_globalIncomingChannel != null) {
      debugPrint('[CallService] Global listener channel already set up. Skipping re-creation.');
      return;
    }

    final sb = Supabase.instance.client;
    final globalChannel = 'incoming_calls_$userId';
    _globalIncomingChannel = sb.channel(globalChannel);

    _globalIncomingChannel!
        .onBroadcast(
      event: 'call_offer',
      callback: (payload) {
        debugPrint('[CallService] Incoming call offer received: $payload');
        if (activeCall.value != null) {
          final channelName = payload['channel'] as String? ??
              _channelName(payload['session_id'] as String? ?? '');
          _broadcastSignal(channelName, {
            'type': 'call_rejected',
            'callee_id': _currentUserId,
            'caller_id': payload['caller_id'],
          });
          return;
        }
        _handleIncomingOffer(payload);
      },
    )
        .subscribe((status, [error]) async {
      debugPrint('[CallService] Global listener status: $status, error: $error');

      if (status == RealtimeSubscribeStatus.subscribed) {
        _globalReconnectAttempts = 0;
      } else if (status == RealtimeSubscribeStatus.channelError) {
        debugPrint('[CallService] Global listener error. Attempting reconnect...');
        final errorStr = error?.toString() ?? '';
        if (errorStr.contains('InvalidJWTToken') || errorStr.contains('expired')) {
          try {
            await sb.auth.refreshSession();
          } catch (e) {
            debugPrint('[CallService] Error refreshing session: $e');
          }
        }

        _globalReconnectAttempts++;
        final delaySeconds = min(pow(2, _globalReconnectAttempts).toInt(), 30);
        _globalReconnectTimer?.cancel();
        _globalReconnectTimer = Timer(Duration(seconds: delaySeconds), () {
          if (_globalIncomingChannel != null) {
            try {
              _globalIncomingChannel!.unsubscribe();
            } catch (_) {}
            _globalIncomingChannel = null;
          }
          _setupGlobalIncomingListener(userId);
        });
      }
    });
  }

  void _handleIncomingOffer(Map<String, dynamic> payload) {
    try {
      final sdpMap = payload['sdp'] as Map<String, dynamic>?;
      if (sdpMap == null) return;
      final offer = RTCSessionDescription(
        sdpMap['sdp'] as String,
        sdpMap['type'] as String,
      );
      final callTypeStr = payload['call_type'] as String? ?? 'audio';
      final callType = callTypeStr == 'video' ? CallType.video : CallType.audio;
      final sessionId = payload['session_id'] as String? ?? '';
      final channelName = _channelName(sessionId);
      final isGroup = payload['is_group'] == true;
      final groupName = payload['group_name'] as String?;

      incomingCall.value = IncomingCallInfo(
        sessionId: sessionId,
        callerId: payload['caller_id'] as String,
        callerName: payload['caller_name'] as String? ?? 'EduSHAMIIT User',
        callerAvatarUrl: payload['caller_avatar'] as String?,
        callType: callType,
        channelName: channelName,
        offer: offer,
        isGroup: isGroup,
        groupName: groupName,
      );
      debugPrint('[CallService] Incoming call notification from ${payload['caller_name']}');

      _startRingtone();

      _subscribeSignalingChannel(channelName).catchError((e) {
        debugPrint('[CallService] Error early subscribing to incoming channel $channelName: $e');
      });
    } catch (e) {
      debugPrint('[CallService] Error parsing incoming offer: $e');
    }
  }

  Future<void> _subscribeSignalingChannel(String channelName) async {
    final sb = Supabase.instance.client;

    if (_signalingChannel != null &&
        _currentSignalingChannelName == channelName) {
      return;
    }

    if (_signalingChannel != null) {
      _teardownSignaling();
    }

    _signalingChannel = sb.channel(channelName);
    _currentSignalingChannelName = channelName;

    final completer = Completer<void>();

    _signalingChannel!
        .onBroadcast(event: 'call_answer', callback: _onCallAnswer)
        .onBroadcast(event: 'ice_candidate', callback: _onRemoteIceCandidate)
        .onBroadcast(event: 'call_hangup', callback: _onRemoteHangup)
        .onBroadcast(event: 'call_rejected', callback: _onCallRejected)
        .subscribe((status, [error]) {
      debugPrint('[CallService] Signaling channel [$channelName]: $status, error: $error');
      if (status == RealtimeSubscribeStatus.subscribed) {
        if (!completer.isCompleted) {
          completer.complete();
        }
      } else if (status == RealtimeSubscribeStatus.channelError) {
        if (!completer.isCompleted) {
          completer.completeError(
              error ?? Exception('Failed to subscribe to signaling channel'));
        }
      }
    });

    return completer.future;
  }

  void _onCallAnswer(Map<String, dynamic> payload) async {
    debugPrint('[CallService] _onCallAnswer payload received: $payload');
    if (_peerConnection == null) return;
    final callInfo = activeCall.value;
    if (callInfo == null) return;

    final sdpMap = payload['sdp'] as Map<String, dynamic>?;
    if (sdpMap == null) return;

    final answer = RTCSessionDescription(
      sdpMap['sdp'] as String,
      sdpMap['type'] as String,
    );

    try {
      await _peerConnection!.setRemoteDescription(answer);
      await _flushPendingIceCandidates();

      if (!callInfo.sessionId.startsWith('call_') && !callInfo.sessionId.startsWith('incoming_')) {
        await _updateCallStatus(callInfo.sessionId, 'answered');
      }

      activeCall.value!.state = CallState.active;
      onCallStateChanged?.call();
      debugPrint('[CallService] Call answered successfully. WebRTC connected!');
    } catch (e) {
      debugPrint('[CallService] Error setting remote answer: $e');
    }
  }

  void _onRemoteIceCandidate(Map<String, dynamic> payload) async {
    try {
      final candidateMap = payload['candidate'] as Map<String, dynamic>?;
      if (candidateMap == null) return;
      final candidate = RTCIceCandidate(
        candidateMap['candidate'] as String,
        candidateMap['sdpMid'] as String?,
        candidateMap['sdpMLineIndex'] as int?,
      );

      if (_peerConnection == null) {
        _pendingIceCandidates.add(candidate);
        return;
      }

      final remoteDesc = await _peerConnection!.getRemoteDescription();
      if (remoteDesc == null) {
        _pendingIceCandidates.add(candidate);
      } else {
        await _peerConnection!.addCandidate(candidate);
      }
    } catch (e) {
      debugPrint('[CallService] Error adding remote ICE: $e');
    }
  }

  void _onRemoteHangup(Map<String, dynamic> payload) {
    debugPrint('[CallService] _onRemoteHangup received');
    incomingCall.value = null;
    _endCallLocally();
  }

  void _onCallRejected(Map<String, dynamic> payload) {
    debugPrint('[CallService] _onCallRejected received');
    incomingCall.value = null;
    activeCall.value?.state = CallState.ended;
    onCallStateChanged?.call();
    _endCallLocally();
  }

  Future<void> _createPeerConnection() async {
    _peerConnection = await createPeerConnection(_iceConfig);

    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      if (candidate.candidate == null || candidate.candidate!.isEmpty) return;
      final call = activeCall.value;
      if (call == null) return;
      _broadcastSignal(_channelName(call.sessionId), {
        'type': 'ice_candidate',
        'sender_id': _currentUserId,
        'candidate': {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        }
      });
    };

    _peerConnection!.onIceConnectionState = (RTCIceConnectionState state) {
      debugPrint('[CallService] ICE connection state: $state');
      if (state == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          state == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        activeCall.value?.state = CallState.active;
        onCallStateChanged?.call();
      } else if (state == RTCIceConnectionState.RTCIceConnectionStateFailed ||
          state == RTCIceConnectionState.RTCIceConnectionStateDisconnected) {
        _endCallLocally();
      }
    };

    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        onRemoteStream?.call(_remoteStream!);
        debugPrint('[CallService] Remote audio/video stream received');
      }
    };
  }

  Future<MediaStream> _getUserMedia(CallType callType) async {
    final constraints = <String, dynamic>{
      'audio': {
        'echoCancellation': true,
        'noiseSuppression': true,
        'autoGainControl': true,
      },
      'video': callType == CallType.video
          ? {
              'facingMode': 'user',
              'width': {'ideal': 1280},
              'height': {'ideal': 720},
            }
          : false,
    };
    return await navigator.mediaDevices.getUserMedia(constraints);
  }

  Future<void> _flushPendingIceCandidates() async {
    if (_peerConnection == null) return;
    for (final candidate in _pendingIceCandidates) {
      try {
        await _peerConnection!.addCandidate(candidate);
      } catch (_) {}
    }
    _pendingIceCandidates.clear();
  }

  void _broadcastSignal(String channelName, Map<String, dynamic> payload) {
    final sb = Supabase.instance.client;
    final event = payload['type'] as String? ?? 'signal';

    final targetChannel = (_signalingChannel != null &&
            _currentSignalingChannelName == channelName)
        ? _signalingChannel!
        : sb.channel(channelName);

    targetChannel.sendBroadcastMessage(event: event, payload: payload);

    // Broadcast to callee's personal incoming channel for call offers
    if (event == 'call_offer') {
      final isGroup = payload['is_group'] == true;
      final groupMemberIds = (payload['group_member_ids'] as List?)?.cast<String>() ?? [];

      final targetUserIds = <String>{};
      if (isGroup && groupMemberIds.isNotEmpty) {
        targetUserIds.addAll(groupMemberIds.where((id) => id != _currentUserId));
      } else {
        final calleeId = payload['callee_id'] as String? ?? '';
        if (calleeId.isNotEmpty) targetUserIds.add(calleeId);
      }

      for (final targetId in targetUserIds) {
        final incomingChannelName = 'incoming_calls_$targetId';
        final incomingChannel = sb.channel(incomingChannelName);

        incomingChannel.subscribe((status, [error]) {
          if (status == RealtimeSubscribeStatus.subscribed) {
            incomingChannel.sendBroadcastMessage(event: 'call_offer', payload: {
              ...payload,
              'channel': channelName,
            });
            debugPrint('[CallService] Broadcasted call offer to $incomingChannelName');

            Future.delayed(const Duration(seconds: 4), () {
              incomingChannel.unsubscribe().catchError((_) => '');
            });
          } else if (status == RealtimeSubscribeStatus.channelError ||
                     status == RealtimeSubscribeStatus.timedOut) {
            incomingChannel.unsubscribe().catchError((_) => '');
          }
        });
      }
    }
  }

  Future<void> _endCallLocally() async {
    _stopRingtone();
    _peerConnection?.close();
    _peerConnection = null;

    _localStream?.getTracks().forEach((t) => t.stop());
    _localStream = null;

    _remoteStream?.getTracks().forEach((t) => t.stop());
    _remoteStream = null;

    _screenStream?.getTracks().forEach((t) => t.stop());
    _screenStream = null;

    _pendingIceCandidates.clear();
    _isScreenSharing = false;
    _isMuted = false;
    _isCameraOff = false;

    _teardownSignaling();

    activeCall.value = null;
    onCallStateChanged?.call();
    debugPrint('[CallService] Call ended locally, hardware media released');
  }

  void _teardownSignaling() {
    if (_signalingChannel != null) {
      try {
        _signalingChannel!.unsubscribe();
      } catch (_) {}
      _signalingChannel = null;
    }
    _currentSignalingChannelName = null;
  }

  void _startRingtone() {
    if (!kIsWeb) return;
    try {
      startWebRingtone();
      debugPrint('[CallService] Started synthesized incoming ringtone');
    } catch (e) {
      debugPrint('[CallService] Error playing synthesized ringtone: $e');
    }
  }

  void _stopRingtone() {
    if (!kIsWeb) return;
    try {
      stopWebRingtone();
      debugPrint('[CallService] Stopped synthesized incoming ringtone');
    } catch (e) {
      debugPrint('[CallService] Error stopping synthesized ringtone: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BACKEND API CALLS
  // ─────────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> _createCallSession(
      String calleeId, CallType callType) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    final resp = await http.post(
      Uri.parse('$_fastApiBaseUrl/api/calls/initiate'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({'callee_id': calleeId, 'call_type': callType.name}),
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to initiate call session: ${resp.body}');
  }

  Future<void> _updateCallStatus(String sessionId, String status) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';
    await http.put(
      Uri.parse('$_fastApiBaseUrl/api/calls/$sessionId/status'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json'
      },
      body: jsonEncode({'status': status}),
    );
  }

  Future<Map<String, dynamic>?> _fetchIceConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token') ?? '';
      final resp = await http.get(
        Uri.parse('$_fastApiBaseUrl/api/calls/ice-config'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        return body['ice_config'] as Map<String, dynamic>?;
      }
    } catch (_) {}
    return null;
  }

  Future<String> _getCurrentUserName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_name');
    if (name != null && name.isNotEmpty) return name;
    final dataStr = prefs.getString('user_data');
    if (dataStr != null) {
      try {
        final map = jsonDecode(dataStr);
        if (map['full_name'] != null) return map['full_name'].toString();
      } catch (_) {}
    }
    return 'EduSHAMIIT User';
  }

  Future<String?> _getCurrentUserAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final dataStr = prefs.getString('user_data');
    if (dataStr != null) {
      try {
        final map = jsonDecode(dataStr);
        return map['avatar_url']?.toString();
      } catch (_) {}
    }
    return null;
  }
}

