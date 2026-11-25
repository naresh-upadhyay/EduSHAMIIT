import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:edu_shamiit_core/screens/exams/services/exams_api_service.dart';
import 'package:edu_shamiit_core/screens/exams/services/exam_prestart_handoff.dart';
import 'package:edu_shamiit_core/screens/exams/utils/exam_nav_helper.dart';
import 'package:edu_shamiit_core/utils/web_proctor_helper.dart';

/// Universal Responsive Take Exam Interface
/// Designed for All Devices (Mobile, Tablet, Laptop, Desktop).
/// Fully responsive layout adapting between 1-column, 2-column, and 3-column views.
class TakeExamScreen extends ConsumerStatefulWidget {
  final String? examId;
  final Map<String, dynamic>? initialTakeInfoForTest;
  const TakeExamScreen({super.key, this.examId, this.initialTakeInfoForTest});

  @override
  ConsumerState<TakeExamScreen> createState() => _TakeExamScreenState();
}

class _TakeExamScreenState extends ConsumerState<TakeExamScreen> with WidgetsBindingObserver {
  final ExamsApiService _apiService = ExamsApiService.instance;

  bool _isLoading = true;
  String? _errorMessage;

  // Exam and candidate metadata
  Map<String, dynamic> _examData = {};
  Map<String, dynamic> _candidateData = {};
  List<Map<String, dynamic>> _sections = [];
  List<Map<String, dynamic>> _questions = [];

  // Active question and answer state
  int _currentQuestionIndex = 0;
  final Map<String, dynamic> _selectedAnswers = {};
  final Set<String> _markedForReview = {};
  final Set<String> _reportedQuestions = {};

  // Server-authoritative timer
  int _remainingSeconds = 0;
  Timer? _countdownTimer;
  Timer? _autosaveTimer;
  Timer? _pingTimer;

  // Proctoring, LiveKit, WebSocket & enforcement state
  int _warningCount = 0;
  bool _isSaving = false;
  bool _isSubmitting = false;
  bool _isSubmitted = false;
  Map<String, dynamic>? _submissionSummary;

  bool _isPausedByProctor = false;
  String? _pausedReason;
  bool _isTerminated = false;
  String? _terminatedReason;
  bool _requiresReentryApproval = false;
  bool _reentryRequested = false;
  bool _reentryWindowClosed = false;
  final TextEditingController _reentryReasonCtrl = TextEditingController();

  // Live announcements and active warnings from invigilator
  final List<Map<String, dynamic>> _pendingAnnouncements = [];
  String? _lastShownTeacherMessage;
  String? _activeWarningBannerMessage;

  // LiveKit media & permission state (honest browser permission vs active track separation)
  lk.Room? _livekitRoom;
  lk.LocalVideoTrack? _cameraTrack;
  lk.LocalAudioTrack? _micTrack;
  lk.LocalVideoTrack? _screenTrack;
  bool _livekitConnected = false;
  bool _cameraActive = false;
  bool _micActive = false;
  bool _screenShareActive = false;
  String _cameraPermissionState = 'NOT_CHECKED';
  String _micPermissionState = 'NOT_CHECKED';
  String _screenShareState = 'NOT_SHARED';
  bool _micForcedMuted = false;
  bool _cameraForcedDisabled = false;
  bool _networkOnline = true;
  DateTime? _tabHiddenAt;

  // WebSocket & browser lifecycle handles
  WebSocketChannel? _wsChannel;
  StreamSubscription<dynamic>? _wsSubscription;
  Timer? _wsReconnectTimer;
  WebProctorLifecycleSubscription? _webLifecycleSub;
  bool _remoteSessionActive = false;

  // Section accordion & filter state
  String? _activeSectionFilter = 'All';
  String? _expandedPaletteSectionId;

  // Responsive sidebar & compact header toggles
  bool _showLeftPalette = true;
  bool _showRightNavigator = true;
  bool _showTabletSidePanel = true;
  bool _showMobileMetaChips = false;

  // Controllers for text/descriptive questions
  final Map<String, TextEditingController> _textControllers = {};

  bool _isAnswerProvided(dynamic value) {
    if (value == null) return false;
    if (value is List) return value.isNotEmpty;
    if (value is Map) return value.isNotEmpty;
    return value.toString().trim().isNotEmpty;
  }

  int get _answeredCount => _selectedAnswers.values.where(_isAnswerProvided).length;

  bool _isQuestionAnswered(String qId) =>
      _selectedAnswers.containsKey(qId) && _isAnswerProvided(_selectedAnswers[qId]);

  String get _safeSectionFilter {
    final ids = <String>{'All', ..._sections.map((s) => s['id']?.toString() ?? '')};
    return (_activeSectionFilter != null && ids.contains(_activeSectionFilter))
        ? _activeSectionFilter!
        : 'All';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadExamTakeInfo();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _countdownTimer?.cancel();
    _autosaveTimer?.cancel();
    _pingTimer?.cancel();
    _wsReconnectTimer?.cancel();
    _wsSubscription?.cancel();
    try {
      _wsChannel?.sink.close();
    } catch (_) {}
    _webLifecycleSub?.dispose();
    _reentryReasonCtrl.dispose();
    _disposeLivekit();
    for (final c in _textControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _disposeLivekit() async {
    try {
      _cameraTrack?.mediaStreamTrack.stop();
    } catch (_) {}
    try {
      await _cameraTrack?.stop();
      await _cameraTrack?.dispose();
    } catch (_) {}
    try {
      _micTrack?.mediaStreamTrack.stop();
    } catch (_) {}
    try {
      await _micTrack?.stop();
      await _micTrack?.dispose();
    } catch (_) {}
    try {
      _screenTrack?.mediaStreamTrack.stop();
    } catch (_) {}
    try {
      await _screenTrack?.stop();
      await _screenTrack?.dispose();
    } catch (_) {}
    try {
      await _livekitRoom?.disconnect();
      await _livekitRoom?.dispose();
    } catch (_) {}
    ExamPrestartHandoff.stopAndReleaseAll();
    _cameraTrack = null;
    _micTrack = null;
    _screenTrack = null;
    _livekitRoom = null;
    _livekitConnected = false;
    _cameraActive = false;
    _micActive = false;
    _screenShareActive = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _tabHiddenAt ??= DateTime.now();
      _reportProctorEvent(
        'Window focus lost / switched tab',
        'medium',
        eventType: 'tab_switch',
      );
    } else if (state == AppLifecycleState.resumed) {
      _tabHiddenAt = null;
    }
  }

  // ============================================================================
  // DATA INITIALIZATION & TIMER
  // ============================================================================

  Future<void> _loadExamTakeInfo() async {
    final testPayload = widget.initialTakeInfoForTest;
    if (testPayload != null) {
      _applyTakeInfoPayload(testPayload, startRemoteSession: false);
      return;
    }

    final examId = widget.examId;
    if (examId == null || examId.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No Examination ID provided.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _apiService.getExamTakeInfo(examId);
      if (res.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not load examination data. Please check your network connection.';
        });
        return;
      }
      _applyTakeInfoPayload(res, startRemoteSession: true);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading exam: $e';
      });
    }
  }

  void _applyTakeInfoPayload(Map<String, dynamic> res, {required bool startRemoteSession}) {
    final exam = res['exam'] is Map ? Map<String, dynamic>.from(res['exam']) : <String, dynamic>{};
    final candidate = res['candidate'] is Map ? Map<String, dynamic>.from(res['candidate']) : <String, dynamic>{};
    final rawSecs = res['sections'] is List ? List<dynamic>.from(res['sections']) : [];
    final rawQuestions = res['questions'] is List ? List<dynamic>.from(res['questions']) : [];
    final savedAns = res['saved_answers'] is Map ? Map<String, dynamic>.from(res['saved_answers']) : <String, dynamic>{};
    final session = res['session'] is Map ? Map<String, dynamic>.from(res['session']) : null;
    final alreadySubmitted = res['is_submitted'] == true;

    final sections = rawSecs.map((s) => s is Map ? Map<String, dynamic>.from(s) : <String, dynamic>{}).toList();
    final questions = rawQuestions.map((q) => q is Map ? Map<String, dynamic>.from(q) : <String, dynamic>{}).toList();

    if (sections.isNotEmpty) {
      _expandedPaletteSectionId = sections.first['id']?.toString();
    }

    _selectedAnswers.addAll(savedAns);

    if (alreadySubmitted) {
      setState(() {
        _isLoading = false;
        _isSubmitted = true;
        _submissionSummary = res['submission'] is Map ? Map<String, dynamic>.from(res['submission']) : null;
      });
      return;
    }

    int remSeconds = 0;
    if (session != null && session['remaining_seconds'] != null) {
      remSeconds = (session['remaining_seconds'] as num).toInt();
    } else {
      final durationMins = (exam['duration_minutes'] as num?)?.toInt() ?? 90;
      remSeconds = durationMins * 60;
    }

    setState(() {
      _examData = exam;
      _candidateData = candidate;
      _sections = sections;
      _questions = questions;
      _remainingSeconds = remSeconds;
      _remoteSessionActive = startRemoteSession;
      _isLoading = false;
    });

    if (startRemoteSession) {
      _networkOnline = isProctorNetworkOnline();
      _registerBrowserLifecycleProctoring();
      _startOrResumeSession();
      _connectCandidateWebSocket();
      _initLivekitProctoring();
      _startTimer();

      _autosaveTimer = Timer.periodic(const Duration(seconds: 25), (_) {
        _performAutosave();
      });

      _pingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        _performPing();
      });
    }
  }

  DateTime? _lastFocusEventAt;

  void _registerBrowserLifecycleProctoring() {
    _webLifecycleSub?.dispose();
    _webLifecycleSub = registerWebProctorLifecycleListeners(
      onVisibilityHidden: () {
        final now = DateTime.now();
        if (_lastFocusEventAt != null && now.difference(_lastFocusEventAt!).inSeconds < 2) return;
        _lastFocusEventAt = now;
        _tabHiddenAt = now;
        _reportProctorEvent('Browser tab hidden / switched away', 'medium', eventType: 'tab_switch');
      },
      onVisibilityVisible: () {
        if (_tabHiddenAt != null) {
          final dur = DateTime.now().difference(_tabHiddenAt!).inSeconds;
          _tabHiddenAt = null;
          if (dur > 1) {
            _sendWsTelemetry({'duration_seconds': dur, 'is_online': true});
          }
        }
      },
      onBlur: () {
        final now = DateTime.now();
        if (_lastFocusEventAt != null && now.difference(_lastFocusEventAt!).inSeconds < 2) return;
        _lastFocusEventAt = now;
        _reportProctorEvent('Examination window lost focus', 'medium', eventType: 'window_blur');
      },
      onFullscreenChanged: (isFs) {
        if (!isFs && !_isSubmitted && !_isTerminated && !_isPausedByProctor) {
          _reportProctorEvent('Exited fullscreen examination mode', 'low', eventType: 'fullscreen_exit');
        }
      },
      onNetworkChanged: (online) {
        if (!mounted) return;
        setState(() => _networkOnline = online);
        if (online) {
          _performPing();
          _connectCandidateWebSocket();
        }
      },
    );
  }

  String _policyMode(String key, {bool legacyBoolFallback = false}) {
    // 1. Check prestart_config with key aliases
    final cfg = _examData['prestart_config'];
    if (cfg is Map) {
      if (cfg[key] != null) return cfg[key].toString().toUpperCase();
      if ((key == 'mic_mode' || key == 'microphone_mode') && (cfg['microphone_mode'] ?? cfg['mic_mode']) != null) {
        return (cfg['microphone_mode'] ?? cfg['mic_mode']).toString().toUpperCase();
      }
      if ((key == 'screen_mode' || key == 'screen_share_mode') && (cfg['screen_share_mode'] ?? cfg['screen_mode']) != null) {
        return (cfg['screen_share_mode'] ?? cfg['screen_mode']).toString().toUpperCase();
      }
    }

    // 2. Check readiness_policy (from rpc_get_exam_take_info or prestart)
    final policy = _examData['readiness_policy'];
    if (policy is Map) {
      if (policy[key] != null) return policy[key].toString().toUpperCase();
      if ((key == 'mic_mode' || key == 'microphone_mode') && (policy['microphone_mode'] ?? policy['mic_mode']) != null) {
        return (policy['microphone_mode'] ?? policy['mic_mode']).toString().toUpperCase();
      }
      if ((key == 'screen_mode' || key == 'screen_share_mode') && (policy['screen_share_mode'] ?? policy['screen_mode']) != null) {
        return (policy['screen_share_mode'] ?? policy['screen_mode']).toString().toUpperCase();
      }
    }

    // 3. Fallback to legacy booleans or online exam default
    if (legacyBoolFallback) return 'REQUIRED';

    final isOnline = (_examData['exam_type']?.toString().toLowerCase() == 'online') ||
        (_examData['exam_mode']?.toString().toLowerCase().contains('online') == true);
    if (isOnline) {
      if (key == 'camera_mode' || key == 'mic_mode' || key == 'microphone_mode') {
        return 'REQUIRED';
      }
      if (key == 'screen_mode' || key == 'screen_share_mode') {
        return 'OPTIONAL';
      }
    }

    return 'DISABLED';
  }

  Future<void> _startOrResumeSession() async {
    final examId = widget.examId;
    if (examId == null) return;
    try {
      final res = await _apiService.startExamSession(examId);
      if (!mounted) return;
      if (res['is_terminated'] == true) {
        setState(() {
          _isTerminated = true;
          _terminatedReason = res['message']?.toString() ?? 'Your examination attempt was terminated by the invigilator.';
        });
        _disposeLivekit();
        return;
      }
      if (res['is_submitted'] == true) {
        setState(() {
          _isSubmitted = true;
        });
        _disposeLivekit();
        return;
      }
      if (res['requires_reentry_approval'] == true) {
        setState(() {
          _requiresReentryApproval = true;
          _reentryWindowClosed = res['reentry_window_closed'] == true;
          if (res['remaining_seconds'] != null) {
            _remainingSeconds = (res['remaining_seconds'] as num).toInt();
          }
        });
        return;
      }
      setState(() {
        if (res['remaining_seconds'] != null) {
          _remainingSeconds = (res['remaining_seconds'] as num).toInt();
        }
        _isPausedByProctor = res['is_paused'] == true;
        _pausedReason = res['paused_reason']?.toString();
        _warningCount = (res['warnings_count'] as num?)?.toInt() ?? _warningCount;
        final saved = res['saved_answers'];
        if (saved is Map && saved.isNotEmpty) {
          _selectedAnswers.addAll(Map<String, dynamic>.from(saved));
        }
      });
    } catch (_) {}
  }

  Future<void> _initLivekitProctoring() async {
    final examId = widget.examId;
    if (examId == null || _isSubmitted || _isTerminated) return;

    final camMode = _policyMode('camera_mode', legacyBoolFallback: _examData['camera_required'] == true);
    final micMode = _policyMode('microphone_mode', legacyBoolFallback: _examData['mic_required'] == true);
    final screenMode = _policyMode('screen_share_mode', legacyBoolFallback: _examData['screen_share_required'] == true);

    if (camMode == 'DISABLED') {
      _cameraPermissionState = 'NOT_REQUIRED';
    } else if (_cameraPermissionState != 'GRANTED') {
      _cameraPermissionState = camMode == 'REQUIRED' ? 'PENDING' : 'OPTIONAL';
    }

    if (micMode == 'DISABLED') {
      _micPermissionState = 'NOT_REQUIRED';
    } else if (_micPermissionState != 'GRANTED') {
      _micPermissionState = micMode == 'REQUIRED' ? 'PENDING' : 'OPTIONAL';
    }

    if (screenMode == 'DISABLED') {
      _screenShareState = 'NOT_REQUIRED';
    } else if (_screenShareState != 'SHARED') {
      _screenShareState = screenMode == 'REQUIRED' ? 'PENDING' : 'NOT_SHARED';
    }

    if (camMode == 'DISABLED' && micMode == 'DISABLED' && screenMode == 'DISABLED') {
      _sendWsTelemetry(_currentTelemetryMap());
      return;
    }

    try {
      final tokenRes = await _apiService.getExamMonitoringLivekitToken(examId, mode: 'candidate');
      final token = tokenRes['token']?.toString() ?? '';
      final url = tokenRes['livekit_url']?.toString() ?? '';
      if (token.isEmpty || url.isEmpty) {
        _sendWsTelemetry(_currentTelemetryMap());
        return;
      }

      final room = lk.Room(
        roomOptions: const lk.RoomOptions(
          adaptiveStream: true,
          dynacast: true,
        ),
      );
      await room.connect(url, token);
      if (!mounted) {
        await room.disconnect();
        await room.dispose();
        return;
      }
      _livekitRoom = room;
      setState(() => _livekitConnected = true);

      // Listen to peer-to-peer invigilator commands via LiveKit Data Channel (<30ms)
      room.events.listen((event) {
        if (event is lk.DataReceivedEvent) {
          try {
            final raw = utf8.decode(event.data);
            final map = json.decode(raw);
            if (map is Map) {
              _handleCandidateWsMessage(Map<String, dynamic>.from(map));
            }
          } catch (_) {}
        }
      });

      if (camMode != 'DISABLED' && !_cameraForcedDisabled) {
        await _enableAndPublishCamera(reportDenied: camMode == 'REQUIRED');
      }
      if (micMode != 'DISABLED' && !_micForcedMuted) {
        await _enableAndPublishMic(reportDenied: micMode == 'REQUIRED');
      }
      if (ExamPrestartHandoff.hasActiveScreenTrack()) {
        try {
          final handedOffTrack = ExamPrestartHandoff.takeScreenTrack();
          if (handedOffTrack != null) {
            handedOffTrack.mediaStreamTrack.onEnded = () {
              if (!mounted) return;
              setState(() {
                _screenShareActive = false;
                _screenShareState = 'STOPPED';
              });
              _sendWsTelemetry(_currentTelemetryMap());
              _reportProctorEvent(
                'Screen sharing stopped during examination',
                'medium',
                eventType: 'screen_share_stopped',
              );
            };
            await room.localParticipant?.publishVideoTrack(handedOffTrack);
            _screenTrack = handedOffTrack;
            setState(() {
              _screenShareActive = true;
              _screenShareState = 'SHARED';
            });
            debugPrint('[TakeExam] Reused active screen share handed off from pre-start checks.');
          }
        } catch (e) {
          debugPrint('[TakeExam] Error attaching handed-off screen share: $e');
        }
      } else if (screenMode == 'REQUIRED') {
        await _enableAndPublishScreenShare(reportDenied: true);
      }

      _sendWsTelemetry(_currentTelemetryMap());
    } catch (e) {
      if (mounted) setState(() => _livekitConnected = false);
      _sendWsTelemetry(_currentTelemetryMap());
    }
  }

  Future<void> _enableAndPublishCamera({bool reportDenied = false}) async {
    if (_cameraForcedDisabled) return;
    try {
      await _cameraTrack?.stop();
      await _cameraTrack?.dispose();
      final camTrack = await lk.LocalVideoTrack.createCameraTrack();
      camTrack.mediaStreamTrack.onEnded = () {
        if (!mounted) return;
        setState(() {
          _cameraActive = false;
          _cameraPermissionState = 'STOPPED';
        });
        _reportProctorEvent('Camera stream stopped during exam', 'high', eventType: 'camera_off');
      };
      await _livekitRoom?.localParticipant?.publishVideoTrack(camTrack);
      _cameraTrack = camTrack;
      if (mounted) {
        setState(() {
          _cameraActive = true;
          _cameraPermissionState = 'GRANTED';
        });
      }
      _sendWsTelemetry(_currentTelemetryMap());
    } catch (_) {
      if (mounted) {
        setState(() {
          _cameraActive = false;
          _cameraPermissionState = 'DENIED';
        });
      }
      if (reportDenied) {
        _reportProctorEvent('Camera permission denied or unavailable', 'high', eventType: 'camera_denied');
      }
    }
  }

  Future<void> _enableAndPublishMic({bool reportDenied = false}) async {
    if (_micForcedMuted) return;
    try {
      await _micTrack?.stop();
      await _micTrack?.dispose();
      final micTrack = await lk.LocalAudioTrack.create();
      micTrack.mediaStreamTrack.onEnded = () {
        if (!mounted) return;
        setState(() {
          _micActive = false;
          _micPermissionState = 'STOPPED';
        });
        _reportProctorEvent('Microphone track ended during exam', 'medium', eventType: 'mic_muted');
      };
      await _livekitRoom?.localParticipant?.publishAudioTrack(micTrack);
      _micTrack = micTrack;
      if (mounted) {
        setState(() {
          _micActive = true;
          _micPermissionState = 'GRANTED';
        });
      }
      _sendWsTelemetry(_currentTelemetryMap());
    } catch (_) {
      if (mounted) {
        setState(() {
          _micActive = false;
          _micPermissionState = 'DENIED';
        });
      }
      if (reportDenied) {
        _reportProctorEvent('Microphone permission denied or unavailable', 'medium', eventType: 'mic_denied');
      }
    }
  }

  Future<void> _enableAndPublishScreenShare({bool reportDenied = false}) async {
    try {
      await _screenTrack?.stop();
      await _screenTrack?.dispose();
      final screenTrack = await lk.LocalVideoTrack.createScreenShareTrack(
        const lk.ScreenShareCaptureOptions(useiOSBroadcastExtension: true),
      );
      screenTrack.mediaStreamTrack.onEnded = () {
        if (!mounted) return;
        setState(() {
          _screenShareActive = false;
          _screenShareState = 'STOPPED';
        });
        _reportProctorEvent('Screen sharing stopped during examination', 'high', eventType: 'screen_share_stopped');
      };
      await _livekitRoom?.localParticipant?.publishVideoTrack(screenTrack);
      _screenTrack = screenTrack;
      if (mounted) {
        setState(() {
          _screenShareActive = true;
          _screenShareState = 'SHARED';
        });
      }
      _sendWsTelemetry(_currentTelemetryMap());
    } catch (_) {
      if (mounted) {
        setState(() {
          _screenShareActive = false;
          _screenShareState = 'DENIED';
        });
      }
      if (reportDenied) {
        _reportProctorEvent('Screen share permission declined or interrupted', 'high', eventType: 'screen_share_stopped');
      }
    }
  }

  Future<void> _connectCandidateWebSocket() async {
    final examId = widget.examId;
    if (examId == null || !_remoteSessionActive || _isSubmitted || _isTerminated) return;
    _wsReconnectTimer?.cancel();
    await _wsSubscription?.cancel();
    try {
      await _wsChannel?.sink.close();
    } catch (_) {}

    try {
      final wsUri = await _apiService.buildMonitoringWsUri(examId, isInvigilator: false);
      final channel = WebSocketChannel.connect(wsUri);
      _wsChannel = channel;
      _wsSubscription = channel.stream.listen(
        (raw) {
          try {
            final msg = json.decode(raw.toString());
            if (msg is Map) {
              _handleCandidateWsMessage(Map<String, dynamic>.from(msg));
            }
          } catch (_) {}
        },
        onDone: () => _scheduleWsReconnect(),
        onError: (_) => _scheduleWsReconnect(),
      );
      _sendWsTelemetry(_currentTelemetryMap());
    } catch (_) {
      _scheduleWsReconnect();
    }
  }

  void _scheduleWsReconnect() {
    if (!mounted || !_remoteSessionActive || _isSubmitted || _isTerminated) return;
    _wsReconnectTimer?.cancel();
    _wsReconnectTimer = Timer(const Duration(seconds: 4), _connectCandidateWebSocket);
  }

  void _sendWsTelemetry(Map<String, dynamic> payload) {
    try {
      _wsChannel?.sink.add(json.encode({
        'type': 'telemetry',
        'payload': payload,
      }));
    } catch (_) {}
  }

  Future<void> _handleCandidateWsMessage(Map<String, dynamic> envelope) async {
    if (!mounted) return;
    final event = (envelope['event'] ?? '').toString();
    final data = envelope['data'] is Map ? Map<String, dynamic>.from(envelope['data']) : <String, dynamic>{};

    if (event == 'heartbeat_ack') {
      setState(() {
        if (data['remaining_seconds'] != null) {
          _remainingSeconds = (data['remaining_seconds'] as num).toInt();
        }
        _isPausedByProctor = data['is_paused'] == true;
        _pausedReason = data['paused_reason']?.toString();
        final unack = data['unacknowledged_announcements'];
        if (unack is List) {
          for (final a in unack) {
            if (a is Map && !_pendingAnnouncements.any((x) => x['id'] == a['id'])) {
              _pendingAnnouncements.insert(0, Map<String, dynamic>.from(a));
            }
          }
        }
      });
      return;
    }

    if (event == 'exam_announcement') {
      setState(() {
        if (!_pendingAnnouncements.any((x) => x['id'] == data['id'])) {
          _pendingAnnouncements.insert(0, data);
        }
      });
      return;
    }

    if (event == 'exam_control_updated') {
      final ctrl = (data['control_action'] ?? '').toString();
      if (ctrl == 'pause_exam') {
        setState(() {
          _isPausedByProctor = true;
          _pausedReason = data['reason']?.toString() ?? 'Examination paused by invigilator';
        });
      } else if (ctrl == 'resume_exam') {
        setState(() {
          _isPausedByProctor = false;
          _pausedReason = null;
        });
        _performPing();
      } else if (ctrl == 'extend_exam_deadline') {
        final mins = (data['minutes'] as num?)?.toInt() ?? 0;
        if (mins > 0) {
          setState(() => _remainingSeconds += mins * 60);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Exam deadline extended by $mins minute(s).'), backgroundColor: const Color(0xFF2563EB)),
          );
        }
      } else if (ctrl == 'emergency_submit_all') {
        _submitExam(isAutoSubmit: true);
      }
      return;
    }

    if (event == 'invigilator_command') {
      final cmd = (data['command'] ?? '').toString();
      final msg = data['message']?.toString() ?? data['reason']?.toString() ?? '';
      if (data['remaining_seconds'] != null) {
        _remainingSeconds = (data['remaining_seconds'] as num).toInt();
      }
      if (data['warnings_count'] != null) {
        _warningCount = (data['warnings_count'] as num).toInt();
      }

      if (cmd == 'pause') {
        setState(() {
          _isPausedByProctor = true;
          _pausedReason = msg.isNotEmpty ? msg : 'Your examination session was paused by the invigilator.';
        });
      } else if (cmd == 'resume' || cmd == 'approve_reentry' || cmd == 'reopen') {
        setState(() {
          _isPausedByProctor = false;
          _pausedReason = null;
          _requiresReentryApproval = false;
          _reentryRequested = false;
          _isTerminated = false;
        });
        _performPing();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg.isNotEmpty ? msg : 'Session resumed by invigilator.'), backgroundColor: const Color(0xFF16A34A)),
        );
      } else if (cmd == 'reject_reentry') {
        setState(() {
          _reentryRequested = false;
          _terminatedReason = msg.isNotEmpty ? msg : 'Re-entry request was declined by the invigilator.';
        });
      } else if (cmd == 'extend_time') {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg.isNotEmpty ? msg : 'Additional time granted by invigilator.'), backgroundColor: const Color(0xFF2563EB)),
        );
      } else if (cmd == 'give_chance') {
        setState(() {
          _isPausedByProctor = false;
          _pausedReason = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg.isNotEmpty ? msg : 'Extra chance granted — stay focused.'), backgroundColor: const Color(0xFF16A34A)),
        );
      } else if (cmd == 'warn' || cmd == 'warning' || cmd == 'send_warning' || cmd == 'proctor_warning' || cmd.contains('warn')) {
        final wMsg = msg.isNotEmpty ? msg : 'Invigilator issued an official proctoring warning. Please stay on the exam screen.';
        setState(() {
          _activeWarningBannerMessage = wMsg;
          _warningCount = data['warnings_count'] != null ? (data['warnings_count'] as num).toInt() : (_warningCount + 1);
        });
        _showOfficialWarningDialog(wMsg);
      } else if (cmd == 'terminate') {
        _countdownTimer?.cancel();
        _autosaveTimer?.cancel();
        _disposeLivekit();
        setState(() {
          _isTerminated = true;
          _terminatedReason = msg.isNotEmpty ? msg : 'Examination session terminated by invigilator.';
        });
      } else if (cmd == 'force_submit') {
        _submitExam(isAutoSubmit: true);
      } else if (cmd == 'force_mute_mic' || cmd == 'mute_mic' || cmd == 'turn_off_mic') {
        _micForcedMuted = true;
        try {
          for (final pub in List.from(_livekitRoom?.localParticipant?.audioTrackPublications ?? [])) {
            await _livekitRoom?.localParticipant?.removePublishedTrack(pub.sid);
          }
          _micTrack?.mediaStreamTrack.stop();
          await _micTrack?.stop();
          await _micTrack?.dispose();
        } catch (_) {}
        _micTrack = null;
        setState(() {
          _micActive = false;
          _micPermissionState = 'STOPPED';
        });
        _sendWsTelemetry(_currentTelemetryMap());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Your microphone was turned off by the invigilator.'), backgroundColor: Color(0xFFD97706)),
          );
        }
      } else if (cmd == 'unmute_mic' || cmd == 'enable_mic' || cmd == 'turn_on_mic') {
        _micForcedMuted = false;
        await _enableAndPublishMic(reportDenied: false);
        _sendWsTelemetry(_currentTelemetryMap());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Your microphone was enabled by the invigilator.'), backgroundColor: Color(0xFF16A34A)),
          );
        }
      } else if (cmd == 'force_disable_cam' || cmd == 'disable_cam' || cmd == 'turn_off_cam') {
        _cameraForcedDisabled = true;
        try {
          for (final pub in List.from(_livekitRoom?.localParticipant?.videoTrackPublications ?? [])) {
            if (pub.source == lk.TrackSource.camera) {
              await _livekitRoom?.localParticipant?.removePublishedTrack(pub.sid);
            }
          }
          _cameraTrack?.mediaStreamTrack.stop();
          await _cameraTrack?.stop();
          await _cameraTrack?.dispose();
        } catch (_) {}
        _cameraTrack = null;
        setState(() {
          _cameraActive = false;
          _cameraPermissionState = 'STOPPED';
        });
        _sendWsTelemetry(_currentTelemetryMap());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Your camera was turned off by the invigilator.'), backgroundColor: Color(0xFFD97706)),
          );
        }
      } else if (cmd == 'enable_cam' || cmd == 'turn_on_cam') {
        _cameraForcedDisabled = false;
        await _enableAndPublishCamera(reportDenied: false);
        _sendWsTelemetry(_currentTelemetryMap());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Your camera was enabled by the invigilator.'), backgroundColor: Color(0xFF16A34A)),
          );
        }
      } else if (cmd == 'request_camera' || cmd == 'request_mic' || cmd == 'request_screen_share') {
        if (cmd == 'request_camera') _cameraForcedDisabled = false;
        if (cmd == 'request_mic') _micForcedMuted = false;
        _showConsentDevicePromptDialog(cmd, msg);
      }
    }
  }

  void _showOfficialWarningDialog(String message) {
    if (!mounted) return;
    final palette = _TakeExamPalette.of(context);
    showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 24),
            const SizedBox(width: 10),
            Text('Invigilator Warning', style: TextStyle(color: palette.primaryText, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: TextStyle(color: palette.primaryText, fontSize: 14, height: 1.45),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFFD97706)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Total Warning Notices: $_warningCount',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFD97706)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD97706),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
            child: const Text('I Understand', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showConsentDevicePromptDialog(String cmd, String reason) {
    final palette = _TakeExamPalette.of(context);
    final label = cmd == 'request_camera'
        ? 'Camera'
        : (cmd == 'request_mic' ? 'Microphone' : 'Screen Share');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Icon(Icons.videocam_rounded, color: palette.accentBlue),
            const SizedBox(width: 8),
            Text('$label Re-check Requested', style: TextStyle(color: palette.primaryText, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Text(
          reason.isNotEmpty
              ? '$reason\n\nPlease explicitly grant browser/device permission below.'
              : 'The invigilator has requested that you enable your $label feed. Click below to grant permission.',
          style: TextStyle(color: palette.secondaryText, fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Dismiss'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (cmd == 'request_camera') _enableAndPublishCamera(reportDenied: false);
              if (cmd == 'request_mic') _enableAndPublishMic(reportDenied: false);
              if (cmd == 'request_screen_share') _enableAndPublishScreenShare(reportDenied: false);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            child: Text('Enable $label', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _currentTelemetryMap() {
    return {
      'is_online': _networkOnline,
      'camera_active': _cameraActive,
      'camera_permission_state': _cameraPermissionState,
      'mic_active': _micActive,
      'mic_permission_state': _micPermissionState,
      'screen_share_active': _screenShareActive,
      'screen_share_state': _screenShareState,
      'livekit_connected': _livekitConnected,
      'network_status': _networkOnline ? 'GOOD' : 'OFFLINE',
      'browser_info': getProctorBrowserSummary(),
      'answered_count': _answeredCount,
      'marked_count': _markedForReview.length,
      'current_question_index': _currentQuestionIndex,
    };
  }

  void _startTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_isPausedByProctor || _isTerminated || _requiresReentryApproval || _isSubmitted) {
        return;
      }
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        timer.cancel();
        _handleAutoSubmit();
      }
    });
  }

  String _formatTimer(int totalSeconds) {
    if (totalSeconds < 0) totalSeconds = 0;
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // ============================================================================
  // AUTOSAVE, PING & PROCTORING
  // ============================================================================

  Future<void> _performAutosave() async {
    final examId = widget.examId;
    if (examId == null || _isSubmitted || _isTerminated || _isSaving) return;

    final currentQ = _currentQuestion;
    final qId = currentQ?['id']?.toString();

    if (qId != null && _textControllers.containsKey(qId)) {
      _selectedAnswers[qId] = _textControllers[qId]!.text;
    }

    setState(() => _isSaving = true);
    try {
      await _apiService.saveExamAnswer(
        examId,
        answers: _selectedAnswers,
        currentQuestionId: qId,
      );
    } catch (_) {} finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _performPing() async {
    final examId = widget.examId;
    if (examId == null || _isSubmitted || _isTerminated) return;
    try {
      final res = await _apiService.pingExamSession(examId);
      if (!mounted) return;
      setState(() {
        if (res['remaining_seconds'] != null) {
          _remainingSeconds = (res['remaining_seconds'] as num).toInt();
        }
        _isPausedByProctor = res['is_paused'] == true;
        _pausedReason = res['paused_reason']?.toString();
        _isTerminated = res['terminated'] == true;
        
        final newWarnings = (res['warnings_count'] as num?)?.toInt() ?? _warningCount;
        final teacherMsg = res['teacher_message']?.toString();
        final hasNewWarning = newWarnings > _warningCount;
        final hasNewTeacherMsg = teacherMsg != null && teacherMsg.trim().isNotEmpty && teacherMsg != _lastShownTeacherMessage;

        if (hasNewWarning || hasNewTeacherMsg) {
          _lastShownTeacherMessage = teacherMsg;
          _warningCount = newWarnings;
          final finalMsg = (teacherMsg != null && teacherMsg.trim().isNotEmpty)
              ? teacherMsg
              : 'Invigilator issued an official proctoring warning. Please stay on the exam screen.';
          _activeWarningBannerMessage = finalMsg;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _showOfficialWarningDialog(finalMsg);
            }
          });
        } else if (res['warnings_count'] != null) {
          _warningCount = (res['warnings_count'] as num).toInt();
        }

        // Synchronize remote camera toggling by invigilator
        if (res['camera_active'] == false && (_cameraActive || !_cameraForcedDisabled)) {
          _cameraForcedDisabled = true;
          try {
            for (final pub in List.from(_livekitRoom?.localParticipant?.videoTrackPublications ?? [])) {
              if (pub.source == lk.TrackSource.camera) {
                _livekitRoom?.localParticipant?.removePublishedTrack(pub.sid);
              }
            }
            _cameraTrack?.mediaStreamTrack.stop();
            _cameraTrack?.stop();
            _cameraTrack?.dispose();
          } catch (_) {}
          _cameraTrack = null;
          _cameraActive = false;
          _cameraPermissionState = 'STOPPED';
        } else if (res['camera_active'] == true && !_cameraActive && !_cameraForcedDisabled) {
          _enableAndPublishCamera(reportDenied: false);
        }

        // Synchronize remote microphone toggling by invigilator
        if (res['mic_active'] == false && (_micActive || !_micForcedMuted)) {
          _micForcedMuted = true;
          try {
            for (final pub in List.from(_livekitRoom?.localParticipant?.audioTrackPublications ?? [])) {
              _livekitRoom?.localParticipant?.removePublishedTrack(pub.sid);
            }
            _micTrack?.mediaStreamTrack.stop();
            _micTrack?.stop();
            _micTrack?.dispose();
          } catch (_) {}
          _micTrack = null;
          _micActive = false;
          _micPermissionState = 'STOPPED';
        } else if (res['mic_active'] == true && !_micActive && !_micForcedMuted) {
          _enableAndPublishMic(reportDenied: false);
        }

        final unack = res['unacknowledged_announcements'];
        if (unack is List) {
          for (final a in unack) {
            if (a is Map && !_pendingAnnouncements.any((x) => x['id'] == a['id'])) {
              _pendingAnnouncements.insert(0, Map<String, dynamic>.from(a));
            }
          }
        }
      });
      _sendWsTelemetry(_currentTelemetryMap());
      if (res['expired'] == true) {
        _handleAutoSubmit();
      }
    } catch (_) {}
  }

  Future<void> _reportProctorEvent(
    String event,
    String severity, {
    String? eventType,
  }) async {
    final examId = widget.examId;
    if (examId == null || !_remoteSessionActive || _isSubmitted || _isTerminated) return;
    if (mounted) setState(() => _warningCount++);
    final payload = {
      ..._currentTelemetryMap(),
      'event': event,
      'event_type': eventType ?? event.toLowerCase().replaceAll(' ', '_'),
      'title': event,
      'severity': severity,
    };
    _sendWsTelemetry(payload);
    try {
      await _apiService.pingExamSession(examId, event: event, severity: severity);
    } catch (_) {}
  }

  // ============================================================================
  // SUBMISSION FLOW
  // ============================================================================

  void _showSubmitConfirmationDialog() {
    final palette = _TakeExamPalette.of(context);
    final total = _questions.length;
    final answered = _answeredCount;
    final unanswered = total - answered;
    final marked = _markedForReview.length;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: palette.borderColor),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: Row(
          children: [
            Icon(Icons.assignment_turned_in_rounded, color: palette.accentBlue, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Submit Examination?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: palette.primaryText),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure you want to complete and submit your examination? Once submitted, your answers cannot be changed.',
                  style: TextStyle(fontSize: 13.5, color: palette.secondaryText, height: 1.45),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: palette.subtleBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: palette.borderColor),
                  ),
                  child: Column(
                    children: [
                      _buildSummaryRow('Total Questions:', '$total', palette.primaryText, palette),
                      const SizedBox(height: 8),
                      _buildSummaryRow('Answered Questions:', '$answered', palette.greenText, palette, isBold: true),
                      const SizedBox(height: 8),
                      _buildSummaryRow(
                        'Unanswered Questions:',
                        '$unanswered',
                        unanswered > 0 ? palette.redText : palette.secondaryText,
                        palette,
                        isBold: unanswered > 0,
                      ),
                      const SizedBox(height: 8),
                      _buildSummaryRow('Marked for Review:', '$marked', palette.amberText, palette),
                    ],
                  ),
                ),
                if (unanswered > 0) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: palette.redBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: palette.redText.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: palette.redText, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'You still have $unanswered unanswered questions!',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette.redText),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: palette.borderColor),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text('Back to Exam', style: TextStyle(color: palette.secondaryText)),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _submitExam(isAutoSubmit: false);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Confirm & Submit', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color color, _TakeExamPalette palette, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: Text(label, style: TextStyle(fontSize: 13, color: palette.secondaryText))),
        const SizedBox(width: 8),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color)),
      ],
    );
  }

  Future<void> _handleAutoSubmit() async {
    if (_isSubmitted || _isSubmitting) return;
    await _submitExam(isAutoSubmit: true);
  }

  Future<void> _submitExam({required bool isAutoSubmit}) async {
    final examId = widget.examId;
    if (examId == null || _isSubmitting) return;

    // Sync any ongoing text fields
    for (final entry in _textControllers.entries) {
      if (entry.value.text.trim().isNotEmpty) {
        _selectedAnswers[entry.key] = entry.value.text.trim();
      }
    }

    setState(() => _isSubmitting = true);

    try {
      final res = await _apiService.submitExam(
        examId,
        answers: _selectedAnswers,
        isAutoSubmit: isAutoSubmit,
      );

      _countdownTimer?.cancel();
      _autosaveTimer?.cancel();
      _pingTimer?.cancel();
      _wsReconnectTimer?.cancel();
      _wsSubscription?.cancel();
      try {
        await _wsChannel?.sink.close();
      } catch (_) {}
      _webLifecycleSub?.dispose();
      await _disposeLivekit();

      setState(() {
        _isSubmitting = false;
        _isSubmitted = true;
        _submissionSummary = res;
      });
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error during submission: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ============================================================================
  // QUESTION NAVIGATION & HELPERS
  // ============================================================================

  Map<String, dynamic>? get _currentQuestion {
    if (_questions.isEmpty || _currentQuestionIndex < 0 || _currentQuestionIndex >= _questions.length) {
      return null;
    }
    return _questions[_currentQuestionIndex];
  }

  void _navigateToQuestion(int index) {
    if (index >= 0 && index < _questions.length) {
      final curQ = _currentQuestion;
      if (curQ != null) {
        final qId = curQ['id']?.toString();
        if (qId != null && _textControllers.containsKey(qId)) {
          final txt = _textControllers[qId]!.text;
          if (txt.trim().isNotEmpty) {
            _selectedAnswers[qId] = txt;
          } else {
            _selectedAnswers.remove(qId);
          }
        }
      }

      setState(() {
        _currentQuestionIndex = index;
        final nextSecId = _questions[index]['section_id']?.toString();
        if (nextSecId != null && nextSecId.isNotEmpty) {
          _expandedPaletteSectionId = nextSecId;
        }
      });
    }
  }

  void _toggleMarkForReview(String questionId) {
    setState(() {
      if (_markedForReview.contains(questionId)) {
        _markedForReview.remove(questionId);
      } else {
        _markedForReview.add(questionId);
      }
    });
  }

  void _clearResponse(String questionId) {
    setState(() {
      _selectedAnswers.remove(questionId);
      if (_textControllers.containsKey(questionId)) {
        _textControllers[questionId]!.clear();
      }
    });
  }

  // ============================================================================
  // MAIN BUILD WITH RESPONSIVE LAYOUT
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    final palette = _TakeExamPalette.of(context);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: palette.scaffoldBg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(strokeWidth: 3, color: palette.accentBlue),
                const SizedBox(height: 16),
                Text(
                  'Initializing secure examination environment...',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: palette.secondaryText, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: palette.scaffoldBg,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(24),
              constraints: const BoxConstraints(maxWidth: 480),
              decoration: BoxDecoration(
                color: palette.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: palette.borderColor),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: palette.isDark ? 0.2 : 0.04), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline_rounded, color: palette.redText, size: 48),
                  const SizedBox(height: 16),
                  Text('Examination Error', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: palette.primaryText)),
                  const SizedBox(height: 10),
                  Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: palette.secondaryText)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => safeGoBack(context),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                    child: const Text('Return to Examinations', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (_isSubmitted) {
      return _buildSubmittedView(palette);
    }

    if (_isTerminated) {
      return _buildBlockingStatusScaffold(
        palette: palette,
        icon: Icons.gavel_rounded,
        iconColor: palette.redText,
        title: 'Examination Session Terminated',
        message: _terminatedReason ??
            'Your examination attempt has been terminated by the invigilator.',
        secondaryText:
            'Your $_answeredCount saved response(s) have been preserved in the server database.',
        actionLabel: 'Return to Examinations',
        onAction: () => safeGoBack(context),
      );
    }

    if (_requiresReentryApproval) {
      return _buildReentryGateScaffold(palette);
    }

    return PopScope(
      canPop: _isSubmitted || _isTerminated,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _showSaveAndExitDialog();
      },
      child: Scaffold(
        backgroundColor: palette.scaffoldBg,
        body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = constraints.maxWidth;
                final maxHeight = constraints.maxHeight;
                final isMobile = maxWidth < 680;
                final isTablet = maxWidth >= 680 && maxWidth < 1080;
                final isDesktop = maxWidth >= 1080;

                return Column(
                  children: [
                    // 1. Sleek Responsive Exam Header & Info Bar
                    _buildResponsiveExamInfoBar(maxWidth, maxHeight, palette),

                    // Official Proctor Warning Banner (Alert strip)
                    if (_activeWarningBannerMessage != null)
                      _buildWarningAlertBanner(palette),

                    // Live Invigilator Announcement Banner if pending
                    if (_pendingAnnouncements.isNotEmpty)
                      _buildAnnouncementBanner(palette),

                    // 2. Responsive Main Question Workspace Area
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 8 : 14,
                          vertical: isMobile ? 6 : 10,
                        ),
                        child: _buildResponsiveBody(
                          maxWidth: maxWidth,
                          maxHeight: maxHeight,
                          isMobile: isMobile,
                          isTablet: isTablet,
                          isDesktop: isDesktop,
                          palette: palette,
                        ),
                      ),
                    ),

                    // 3. Sticky Bottom Action Bar
                    _buildStickyBottomBar(maxWidth, isMobile, palette),
                  ],
                );
              },
            ),

            // Floating compact proctoring live status badge (top-right inside workspace or non-obstructive)
            if (_remoteSessionActive && (_livekitConnected || _cameraActive || _micActive || _screenShareActive))
              Positioned(
                bottom: 66,
                left: 16,
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: palette.cardBg.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: palette.borderColor),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 8),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.fiber_manual_record_rounded,
                          size: 10,
                          color: _livekitConnected ? palette.greenText : palette.amberText,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _livekitConnected ? 'Proctoring Live' : 'Monitoring Active',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: palette.primaryText),
                        ),
                        if (_cameraActive) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.videocam_rounded, size: 13, color: palette.greenText),
                        ],
                        if (_micActive) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.mic_rounded, size: 13, color: palette.greenText),
                        ],
                        if (_screenShareActive) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.screen_share_rounded, size: 13, color: palette.accentBlue),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

            // Authoritative Pause Lock Overlay
            if (_isPausedByProctor)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.72),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 460),
                    padding: const EdgeInsets.all(26),
                    decoration: BoxDecoration(
                      color: palette.cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: palette.amberText.withValues(alpha: 0.45)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 24),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: palette.amberBg,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.pause_circle_filled_rounded, color: palette.amberText, size: 42),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Examination Paused by Invigilator',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: palette.primaryText),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _pausedReason?.isNotEmpty == true
                              ? _pausedReason!
                              : 'Your examination timer has been frozen while the invigilator reviews your session.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13.5, color: palette.secondaryText, height: 1.45),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: palette.subtleBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: palette.borderColor),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'Saved Answers: $_answeredCount • Waiting for Resume',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: palette.primaryText),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildAnnouncementBanner(_TakeExamPalette palette) {
    final ann = _pendingAnnouncements.first;
    final annId = ann['id']?.toString() ?? '';
    final priority = (ann['priority'] ?? 'normal').toString().toLowerCase();
    final isUrgent = priority == 'urgent' || priority == 'important';
    final bg = isUrgent ? palette.amberBg : palette.subtleBg;
    final fg = isUrgent ? palette.amberText : palette.accentBlue;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        border: Border(bottom: BorderSide(color: fg.withValues(alpha: 0.35))),
      ),
      child: Row(
        children: [
          Icon(Icons.campaign_rounded, color: fg, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ann['title']?.toString() ?? 'Announcement',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: palette.primaryText),
                ),
                Text(
                  ann['message']?.toString() ?? '',
                  style: TextStyle(fontSize: 12, color: palette.secondaryText),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: () async {
              final examId = widget.examId;
              setState(() => _pendingAnnouncements.removeWhere((a) => a['id'] == annId));
              if (examId != null && annId.isNotEmpty) {
                await _apiService.acknowledgeMonitoringAnnouncement(examId, annId);
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: fg,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
            child: const Text('Acknowledge', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningAlertBanner(_TakeExamPalette palette) {
    final msg = _activeWarningBannerMessage ?? 'Invigilator issued an official proctoring warning. Please focus on your screen.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFF7F1D1D),
        border: Border(bottom: BorderSide(color: Colors.redAccent.withValues(alpha: 0.6), width: 1.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFFCA5A5), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text(
                      'OFFICIAL INVIGILATOR WARNING',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFFFEE2E2), letterSpacing: 0.5),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Total notices: $_warningCount',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFFCD34D)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  msg,
                  style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: () {
              setState(() => _activeWarningBannerMessage = null);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              elevation: 0,
            ),
            child: const Text('I Understand', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockingStatusScaffold({
    required _TakeExamPalette palette,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required String secondaryText,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Scaffold(
      backgroundColor: palette.scaffoldBg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(28),
            constraints: const BoxConstraints(maxWidth: 480),
            decoration: BoxDecoration(
              color: palette.cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.borderColor),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: palette.isDark ? 0.25 : 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: iconColor, size: 52),
                const SizedBox(height: 16),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: palette.primaryText),
                ),
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, color: palette.secondaryText, height: 1.45),
                ),
                const SizedBox(height: 12),
                Text(
                  secondaryText,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette.accentBlue),
                ),
                const SizedBox(height: 22),
                ElevatedButton(
                  onPressed: onAction,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(actionLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReentryGateScaffold(_TakeExamPalette palette) {
    return Scaffold(
      backgroundColor: palette.scaffoldBg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(28),
            constraints: const BoxConstraints(maxWidth: 490),
            decoration: BoxDecoration(
              color: palette.cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.borderColor),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_clock_rounded, color: palette.amberText, size: 50),
                const SizedBox(height: 14),
                Text(
                  'Invigilator Re-Entry Approval Required',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18.5, fontWeight: FontWeight.bold, color: palette.primaryText),
                ),
                const SizedBox(height: 10),
                Text(
                  _reentryWindowClosed
                      ? 'The re-entry window for this examination has been closed by the invigilator.'
                      : 'Your session was interrupted after exceeding automatic rejoin attempts. Your $_answeredCount saved answer(s) remain safe.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, color: palette.secondaryText, height: 1.45),
                ),
                const SizedBox(height: 18),
                if (!_reentryWindowClosed && !_reentryRequested) ...[
                  TextField(
                    controller: _reentryReasonCtrl,
                    maxLines: 2,
                    style: TextStyle(color: palette.primaryText, fontSize: 13),
                    decoration: InputDecoration(
                      labelText: 'Reason for disconnection',
                      hintText: 'e.g., Network drop or browser refresh',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      OutlinedButton(
                        onPressed: () => safeGoBack(context),
                        child: const Text('Return to Examinations'),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final examId = widget.examId;
                          if (examId == null) return;
                          try {
                            await _apiService.requestExamReentry(
                              examId,
                              reason: _reentryReasonCtrl.text.trim().isEmpty
                                  ? 'Candidate requested examination re-entry'
                                  : _reentryReasonCtrl.text.trim(),
                            );
                            if (mounted) setState(() => _reentryRequested = true);
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('$e'), backgroundColor: Colors.red),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.send_rounded, size: 16),
                        label: const Text('Request Re-Entry Approval'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ] else if (_reentryRequested) ...[
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: palette.amberBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: palette.amberText.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Re-entry request submitted. Waiting for your invigilator to approve... This screen will unlock automatically.',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: palette.primaryText),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  ElevatedButton(
                    onPressed: () => safeGoBack(context),
                    child: const Text('Back to Examinations'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // 1. RESPONSIVE EXAM HEADER & INFO BAR (ALL-SCREEN FRIENDLY)
  // ============================================================================

  Widget _buildResponsiveExamInfoBar(double maxWidth, double maxHeight, _TakeExamPalette palette) {
    final title = _examData['title'] ?? 'Online Examination';
    final subject = _examData['subject'] ?? 'General';
    final classSec = _candidateData['class_name'] ?? 'General';
    final totalQ = _questions.length.toString();
    final totalMarks = _examData['total_marks']?.toString() ?? '100';
    final durationMins = (_examData['duration_minutes'] as num?)?.toInt() ?? 90;
    final durationStr = durationMins >= 60
        ? '${durationMins ~/ 60}h${durationMins % 60 > 0 ? ' ${durationMins % 60}m' : ''}'
        : '$durationMins Mins';
    final candidateName = (_candidateData['name'] ?? 'Candidate').toString();

    final isPhone = maxWidth < 680;
    final isUltraNarrow = maxWidth < 380;
    final isShortHeight = maxHeight < 500;
    final isTimerCritical = _remainingSeconds > 0 && _remainingSeconds <= 300;

    return Container(
      margin: EdgeInsets.fromLTRB(isPhone ? 8 : 14, isPhone ? 6 : 10, isPhone ? 8 : 14, 0),
      padding: EdgeInsets.symmetric(
        horizontal: isPhone ? 10 : 16,
        vertical: isShortHeight ? 8 : (isPhone ? 9 : 11),
      ),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: palette.isDark ? 0.22 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Title, Candidate Pill, Help & Digital Timer
          Row(
            children: [
              if (!isUltraNarrow) ...[
                Container(
                  width: isPhone ? 34 : 40,
                  height: isPhone ? 34 : 40,
                  decoration: BoxDecoration(
                    color: palette.accentBlueSoft,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: palette.accentBlueBorder),
                  ),
                  child: Icon(Icons.assignment_rounded, color: palette.accentBlue, size: isPhone ? 18 : 22),
                ),
                const SizedBox(width: 10),
              ],

              // Exam Title & Portal Subtitle
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: isPhone ? 14 : 16.5,
                              fontWeight: FontWeight.bold,
                              color: palette.primaryText,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (_isSaving) ...[
                          const SizedBox(width: 6),
                          SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(strokeWidth: 1.5, color: palette.accentBlue),
                          ),
                          if (!isPhone) ...[
                            const SizedBox(width: 4),
                            Text('Saving', style: TextStyle(fontSize: 10.5, color: palette.secondaryText)),
                          ],
                        ],
                      ],
                    ),
                    if (!isShortHeight && maxWidth >= 440) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Universal Exam Portal • Answer questions and submit before timer ends.',
                        style: TextStyle(fontSize: isPhone ? 11 : 12, color: palette.secondaryText),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Candidate pill (Tablet & Desktop)
              if (maxWidth >= 740) ...[
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth >= 1080 ? 190 : 145),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: palette.subtleBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: palette.borderColor),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 11,
                          backgroundColor: const Color(0xFF2563EB),
                          child: Text(
                            candidateName.isNotEmpty ? candidateName[0].toUpperCase() : 'C',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            candidateName,
                            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: palette.primaryText),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // Toggle metadata pills on phones / short screens
              if (isPhone || isShortHeight) ...[
                IconButton(
                  icon: Icon(
                    _showMobileMetaChips ? Icons.expand_less_rounded : Icons.info_outline_rounded,
                    color: palette.secondaryText,
                    size: 19,
                  ),
                  tooltip: _showMobileMetaChips ? 'Hide Exam Details' : 'Show Exam Details',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () => setState(() => _showMobileMetaChips = !_showMobileMetaChips),
                ),
                const SizedBox(width: 4),
              ],

              // Instructions / Help Button
              IconButton(
                icon: Icon(Icons.help_outline_rounded, color: palette.secondaryText, size: 19),
                tooltip: 'Exam Instructions',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: () => _showInstructionsDialog(),
              ),

              const SizedBox(width: 6),

              // Digital Countdown Timer Box
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isUltraNarrow ? 8 : (isPhone ? 10 : 14),
                  vertical: isPhone ? 6 : 8,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isTimerCritical
                        ? const [Color(0xFFEF4444), Color(0xFFB91C1C)]
                        : const [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: (isTimerCritical ? const Color(0xFFEF4444) : const Color(0xFF2563EB)).withValues(alpha: 0.28),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time_filled_rounded, color: Colors.white, size: isPhone ? 14 : 16),
                    const SizedBox(width: 5),
                    Text(
                      _formatTimer(_remainingSeconds),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isUltraNarrow ? 13 : (isPhone ? 14 : 17),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.4,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Row 2: Metadata Badges
          if ((!isPhone && !isShortHeight) || _showMobileMetaChips || _warningCount > 0) ...[
            const SizedBox(height: 8),
            Divider(height: 1, color: palette.dividerColor),
            const SizedBox(height: 7),
            if (isPhone && !_showMobileMetaChips)
              // Single compact row when mobile details collapsed (e.g. only when warning exists)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildResponsivePill(Icons.menu_book_rounded, subject, palette),
                  _buildResponsivePill(Icons.verified_outlined, '$totalMarks Marks', palette),
                  if (_warningCount > 0) _buildWarningPill(palette),
                ],
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildResponsivePill(Icons.menu_book_rounded, 'Subject: $subject', palette),
                  _buildResponsivePill(Icons.groups_rounded, 'Target: $classSec', palette),
                  _buildResponsivePill(Icons.format_list_numbered_rounded, 'Total Questions: $totalQ', palette),
                  _buildResponsivePill(Icons.verified_outlined, 'Total Marks: $totalMarks', palette),
                  _buildResponsivePill(Icons.schedule_rounded, 'Duration: $durationStr', palette),
                  if (_warningCount > 0) _buildWarningPill(palette),
                ],
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildWarningPill(_TakeExamPalette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: palette.amberBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: palette.amberText.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.warning_amber_rounded, size: 13, color: palette.amberText),
          const SizedBox(width: 4),
          Text(
            'Tab notices: $_warningCount',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: palette.amberText),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsivePill(IconData icon, String text, _TakeExamPalette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: palette.subtleBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: palette.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: palette.secondaryText),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              style: TextStyle(fontSize: 11.5, color: palette.bodyText, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // 2. RESPONSIVE WORKSPACE BODY
  // ============================================================================

  Widget _buildResponsiveBody({
    required double maxWidth,
    required double maxHeight,
    required bool isMobile,
    required bool isTablet,
    required bool isDesktop,
    required _TakeExamPalette palette,
  }) {
    if (_questions.isEmpty) {
      return _buildNoQuestionsEmptyState(palette);
    }

    if (isDesktop) {
      final leftWidth = maxWidth >= 1340 ? 245.0 : 205.0;
      final rightWidth = maxWidth >= 1340 ? 300.0 : 278.0;

      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_showLeftPalette) ...[
            SizedBox(
              width: leftWidth,
              child: _buildLeftSectionPalette(palette: palette, canCollapse: true),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: _buildCenterQuestionWorkspace(
              isMobile: false,
              isTablet: false,
              palette: palette,
            ),
          ),
          if (_showRightNavigator) ...[
            const SizedBox(width: 12),
            SizedBox(
              width: rightWidth,
              child: _buildRightProgressAndNavigator(palette: palette, canCollapse: true),
            ),
          ],
        ],
      );
    } else if (isTablet) {
      final sideWidth = math.min(315.0, math.max(255.0, maxWidth * 0.35));

      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _buildCenterQuestionWorkspace(
              isMobile: false,
              isTablet: true,
              palette: palette,
            ),
          ),
          if (_showTabletSidePanel) ...[
            const SizedBox(width: 12),
            SizedBox(
              width: sideWidth,
              child: _buildTabletCombinedSidePanel(palette),
            ),
          ],
        ],
      );
    } else {
      // 1-Column Mobile Layout with Quick Sheet Triggers
      return Column(
        children: [
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: palette.cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: palette.borderColor),
            ),
            child: Row(
              children: [
                Flexible(
                  child: OutlinedButton.icon(
                    onPressed: () => _openMobileSectionsSheet(palette),
                    icon: Icon(Icons.list_alt_rounded, size: 15, color: palette.accentBlue),
                    label: Text(
                      'Sections',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: palette.accentBlue, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: const Size(0, 34),
                      side: BorderSide(color: palette.accentBlueBorder),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Q${_currentQuestionIndex + 1}/${_questions.length}',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: palette.primaryText),
                  ),
                ),
                const Spacer(),
                Flexible(
                  child: ElevatedButton.icon(
                    onPressed: () => _openMobileNavigatorSheet(palette),
                    icon: const Icon(Icons.grid_view_rounded, size: 14, color: Colors.white),
                    label: Text(
                      'Grid ($_answeredCount/${_questions.length})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: const Size(0, 34),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _buildCenterQuestionWorkspace(
              isMobile: true,
              isTablet: false,
              palette: palette,
            ),
          ),
        ],
      );
    }
  }

  // ============================================================================
  // EMPTY STATE (NO QUESTIONS IN EXAM)
  // ============================================================================

  Widget _buildNoQuestionsEmptyState(_TakeExamPalette palette) {
    final title = _examData['title'] ?? 'Examination';
    final base = getExamsBaseRoute(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(28),
          constraints: const BoxConstraints(maxWidth: 500),
          decoration: BoxDecoration(
            color: palette.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: palette.borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: palette.isDark ? 0.22 : 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: palette.accentBlueSoft,
                  shape: BoxShape.circle,
                  border: Border.all(color: palette.accentBlueBorder),
                ),
                child: Icon(Icons.assignment_late_outlined, color: palette.accentBlue, size: 30),
              ),
              const SizedBox(height: 16),
              Text(
                'No Questions Configured Yet',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: palette.primaryText),
              ),
              const SizedBox(height: 8),
              Text(
                'Examination "$title" has no questions added to its paper yet. Add questions in the Paper Builder to take this test.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: palette.secondaryText, height: 1.45),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => safeGoBack(context),
                    icon: Icon(Icons.arrow_back_rounded, size: 16, color: palette.primaryText),
                    label: Text('Back to Exams', style: TextStyle(color: palette.primaryText)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: palette.borderColor),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      context.go('$base/paper-builder?examId=${widget.examId}');
                    },
                    icon: const Icon(Icons.build_rounded, size: 16, color: Colors.white),
                    label: const Text('Build Paper', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // 3. LEFT COLUMN — SECTION PALETTE
  // ============================================================================

  Widget _buildLeftSectionPalette({required _TakeExamPalette palette, bool canCollapse = false}) {
    return Container(
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(Icons.format_list_bulleted_rounded, size: 16, color: palette.accentBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Sections',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: palette.primaryText),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (canCollapse)
                  IconButton(
                    icon: Icon(Icons.first_page_rounded, size: 18, color: palette.secondaryText),
                    tooltip: 'Collapse sections',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    onPressed: () => setState(() => _showLeftPalette = false),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: palette.borderColor),

          Expanded(
            child: _sections.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Section A — All Questions', style: TextStyle(fontSize: 12, color: palette.secondaryText)),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(10),
                    itemCount: _sections.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final sec = _sections[index];
                      final secId = sec['id']?.toString() ?? 'sec-$index';
                      final secName = sec['name']?.toString() ?? 'Section ${String.fromCharCode(65 + index)}';
                      final isSelected = _expandedPaletteSectionId == secId;

                      final secQuestions = _questions.where((q) => q['section_id']?.toString() == secId).toList();
                      final rangeStr = secQuestions.isNotEmpty
                          ? '(${_questions.indexOf(secQuestions.first) + 1} - ${_questions.indexOf(secQuestions.last) + 1})'
                          : '';

                      return InkWell(
                        onTap: () {
                          setState(() {
                            _expandedPaletteSectionId = secId;
                          });
                          if (secQuestions.isNotEmpty) {
                            _navigateToQuestion(_questions.indexOf(secQuestions.first));
                          }
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF2563EB) : palette.subtleBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF2563EB) : palette.borderColor,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '$secName $rangeStr',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected ? Colors.white : palette.bodyText,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                isSelected ? Icons.keyboard_arrow_down_rounded : Icons.keyboard_arrow_right_rounded,
                                color: isSelected ? Colors.white : palette.secondaryText,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // 4. CENTER COLUMN — MAIN QUESTION WORKSPACE
  // ============================================================================

  Widget _buildCenterQuestionWorkspace({
    required bool isMobile,
    required bool isTablet,
    required _TakeExamPalette palette,
  }) {
    final curQ = _currentQuestion;
    if (curQ == null) {
      return Container(
        decoration: BoxDecoration(
          color: palette.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.borderColor),
        ),
        child: Center(child: Text('No active question.', style: TextStyle(color: palette.secondaryText))),
      );
    }

    final qId = curQ['id']?.toString() ?? 'q_$_currentQuestionIndex';
    final secName = curQ['section_name']?.toString() ?? 'Section A — Multiple Choice Questions';
    final marks = curQ['marks']?.toString() ?? '1';
    final negMarks = (curQ['negative_marks'] as num?)?.toDouble() ?? 0.0;
    final isMarked = _markedForReview.contains(qId);
    final isReported = _reportedQuestions.contains(qId);

    // Resolve optional attached diagram image URL from snapshot_data
    final diagramUrl = _extractDiagramImageUrl(curQ);

    return Column(
      children: [
        // Section Header Strip
        Container(
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 14, vertical: isMobile ? 8 : 10),
          decoration: BoxDecoration(
            color: palette.cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: palette.borderColor),
          ),
          child: Row(
            children: [
              if (!_showLeftPalette && !isMobile && !isTablet) ...[
                IconButton(
                  icon: Icon(Icons.menu_rounded, size: 18, color: palette.accentBlue),
                  tooltip: 'Show sections',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () => setState(() => _showLeftPalette = true),
                ),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  secName,
                  style: TextStyle(
                    fontSize: isMobile ? 12.5 : 13.5,
                    fontWeight: FontWeight.bold,
                    color: palette.primaryText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.chevron_left_rounded,
                  size: 22,
                  color: _currentQuestionIndex > 0 ? palette.accentBlue : palette.secondaryText.withValues(alpha: 0.4),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: _currentQuestionIndex > 0 ? () => _navigateToQuestion(_currentQuestionIndex - 1) : null,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  '${_currentQuestionIndex + 1} / ${_questions.length}',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: palette.primaryText),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: _currentQuestionIndex < _questions.length - 1 ? palette.accentBlue : palette.secondaryText.withValues(alpha: 0.4),
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: _currentQuestionIndex < _questions.length - 1 ? () => _navigateToQuestion(_currentQuestionIndex + 1) : null,
              ),
              if (!_showRightNavigator && !isMobile && !isTablet) ...[
                const SizedBox(width: 6),
                IconButton(
                  icon: Icon(Icons.grid_view_rounded, size: 18, color: palette.accentBlue),
                  tooltip: 'Show question grid',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () => setState(() => _showRightNavigator = true),
                ),
              ],
              if (isTablet) ...[
                const SizedBox(width: 6),
                IconButton(
                  icon: Icon(
                    _showTabletSidePanel ? Icons.last_page_rounded : Icons.view_sidebar_outlined,
                    size: 18,
                    color: palette.accentBlue,
                  ),
                  tooltip: _showTabletSidePanel ? 'Hide side panel' : 'Show side panel',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                  onPressed: () => setState(() => _showTabletSidePanel = !_showTabletSidePanel),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Main Question Statement, Media & Inputs Card
        Expanded(
          child: Container(
            padding: EdgeInsets.all(isMobile ? 12 : 18),
            decoration: BoxDecoration(
              color: palette.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: palette.borderColor),
            ),
            child: LayoutBuilder(
              builder: (context, cardConstraints) {
                final questionBody = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: palette.accentBlueSoft,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: palette.accentBlueBorder),
                          ),
                          child: Text(
                            'Q${_currentQuestionIndex + 1}',
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: palette.accentBlue),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            curQ['question_text']?.toString() ?? 'Question Statement',
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 15,
                              fontWeight: FontWeight.w600,
                              color: palette.primaryText,
                              height: 1.45,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: palette.mutedBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'Marks: $marks',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: palette.bodyText),
                              ),
                            ),
                            if (negMarks > 0) ...[
                              const SizedBox(height: 4),
                              Text(
                                '-$negMarks neg.',
                                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: palette.redText),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    if (diagramUrl != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: palette.subtleBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: palette.borderColor),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxHeight: isMobile ? 190 : 260),
                            child: Image.network(
                              diagramUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(
                                  'Unable to load attached diagram.',
                                  style: TextStyle(fontSize: 12, color: palette.secondaryText),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _buildQuestionInputWidget(curQ, palette),
                  ],
                );

                final actionBar = Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _toggleMarkForReview(qId),
                      icon: Icon(
                        isMarked ? Icons.bookmark_added_rounded : Icons.bookmark_border_rounded,
                        size: 15,
                        color: isMarked ? palette.amberText : palette.secondaryText,
                      ),
                      label: Text(
                        isMarked ? 'Marked for Review' : 'Mark for Review',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isMarked ? palette.amberText : palette.bodyText,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isMarked ? palette.amberBg : palette.cardBg,
                        side: BorderSide(color: isMarked ? palette.amberText.withValues(alpha: 0.5) : palette.borderColor),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          if (isReported) {
                            _reportedQuestions.remove(qId);
                          } else {
                            _reportedQuestions.add(qId);
                          }
                        });
                      },
                      icon: Icon(
                        isReported ? Icons.flag_rounded : Icons.outlined_flag_rounded,
                        size: 15,
                        color: isReported ? palette.redText : palette.secondaryText,
                      ),
                      label: Text(
                        isReported ? 'Reported' : 'Report',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isReported ? palette.redText : palette.bodyText,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: isReported ? palette.redText.withValues(alpha: 0.5) : palette.borderColor),
                        backgroundColor: isReported ? palette.redBg : palette.cardBg,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    if (_isQuestionAnswered(qId))
                      TextButton.icon(
                        onPressed: () => _clearResponse(qId),
                        icon: Icon(Icons.clear_rounded, size: 15, color: palette.secondaryText),
                        label: Text('Clear Response', style: TextStyle(fontSize: 12, color: palette.secondaryText)),
                      ),
                  ],
                );

                // On short viewports (e.g. mobile landscape), scroll question + actions together cleanly
                if (cardConstraints.maxHeight < 220) {
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        questionBody,
                        const SizedBox(height: 12),
                        Divider(height: 1, color: palette.borderColor),
                        const SizedBox(height: 10),
                        actionBar,
                      ],
                    ),
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: questionBody,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Divider(height: 1, color: palette.borderColor),
                    const SizedBox(height: 10),
                    actionBar,
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  String? _extractDiagramImageUrl(Map<String, dynamic> q) {
    final snap = q['snapshot_data'];
    if (snap is Map) {
      final direct = snap['image_url']?.toString();
      if (direct != null && direct.trim().isNotEmpty) return direct.trim();
      final atts = snap['attachments'];
      if (atts is List && atts.isNotEmpty) {
        final first = atts.first;
        if (first is String && (first.startsWith('http') || first.startsWith('data:image'))) return first;
        if (first is Map && first['url'] != null && first['url'].toString().trim().isNotEmpty) {
          return first['url'].toString().trim();
        }
      }
    }
    final qImg = q['image_url']?.toString();
    if (qImg != null && qImg.trim().isNotEmpty) return qImg.trim();
    return null;
  }

  // ============================================================================
  // QUESTION INPUT BUILDER (MCQ, MULTI-SELECT, DESCRIPTIVE, FILL BLANK, DIAGRAM)
  // ============================================================================

  Widget _buildQuestionInputWidget(Map<String, dynamic> q, _TakeExamPalette palette) {
    final qId = q['id']?.toString() ?? 'q_$_currentQuestionIndex';
    final qType = (q['question_type'] ?? 'mcq').toString().toLowerCase().trim();
    final rawOptions = q['options'];
    final snap = q['snapshot_data'] is Map ? Map<String, dynamic>.from(q['snapshot_data']) : <String, dynamic>{};

    List<Map<String, dynamic>> options = [];
    if (rawOptions is List) {
      options = rawOptions.map((opt) {
        if (opt is Map) return Map<String, dynamic>.from(opt);
        return {'text': opt.toString(), 'value': opt.toString()};
      }).toList();
    }

    if (qType == 'mcq' || qType == 'single_select' || qType == 'true_false' || qType == 'boolean' || qType == 'assertion_reason') {
      return _buildSingleSelectOptions(qId, options, palette);
    } else if (qType == 'multi_select' || qType == 'multiple_choice' || qType.contains('multi')) {
      return _buildMultiSelectOptions(qId, options, palette);
    } else if (qType == 'diagram' || qType.contains('image')) {
      final fmt = (snap['answer_format'] ?? (options.isNotEmpty ? 'mcq' : 'descriptive')).toString().toLowerCase();
      if (fmt == 'multi_select') return _buildMultiSelectOptions(qId, options, palette);
      if (fmt == 'mcq' && options.isNotEmpty) return _buildSingleSelectOptions(qId, options, palette);
      return _buildDescriptiveInput(qId, palette);
    } else if (qType == 'fill_blank' || qType == 'fill_in_the_blanks' || qType == 'numerical') {
      return _buildFillBlankInput(qId, palette);
    } else {
      return _buildDescriptiveInput(qId, palette);
    }
  }

  Widget _buildSingleSelectOptions(String qId, List<Map<String, dynamic>> options, _TakeExamPalette palette) {
    final currentSelection = _selectedAnswers[qId]?.toString();

    if (options.isEmpty) {
      options = [
        {'label': 'A', 'text': 'Option A', 'value': 'A'},
        {'label': 'B', 'text': 'Option B', 'value': 'B'},
        {'label': 'C', 'text': 'Option C', 'value': 'C'},
        {'label': 'D', 'text': 'Option D', 'value': 'D'},
      ];
    }

    return Column(
      children: options.map((opt) {
        final optVal = opt['value']?.toString() ?? opt['text']?.toString() ?? '';
        final optText = opt['text']?.toString() ?? optVal;
        final optLabel = opt['label']?.toString() ?? String.fromCharCode(65 + options.indexOf(opt));
        final isSelected = currentSelection == optVal || currentSelection == optText;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedAnswers[qId] = optVal;
              });
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? palette.accentBlueSoft : palette.subtleBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? palette.accentBlue : palette.borderColor,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(top: 1),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? palette.accentBlue : palette.secondaryText.withValues(alpha: 0.6),
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? Center(
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: palette.accentBlue,
                              ),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$optLabel.  ',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? palette.accentBlue : palette.primaryText,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      optText,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: isSelected ? palette.primaryText : palette.bodyText,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMultiSelectOptions(String qId, List<Map<String, dynamic>> options, _TakeExamPalette palette) {
    final currentList = (_selectedAnswers[qId] is List)
        ? List<String>.from(_selectedAnswers[qId].map((e) => e.toString()))
        : <String>[];

    return Column(
      children: options.map((opt) {
        final optVal = opt['value']?.toString() ?? opt['text']?.toString() ?? '';
        final optText = opt['text']?.toString() ?? optVal;
        final optLabel = opt['label']?.toString() ?? String.fromCharCode(65 + options.indexOf(opt));
        final isSelected = currentList.contains(optVal);

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: InkWell(
            onTap: () {
              setState(() {
                if (isSelected) {
                  currentList.remove(optVal);
                } else {
                  currentList.add(optVal);
                }
                if (currentList.isEmpty) {
                  _selectedAnswers.remove(qId);
                } else {
                  _selectedAnswers[qId] = currentList;
                }
              });
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? palette.accentBlueSoft : palette.subtleBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? palette.accentBlue : palette.borderColor,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(top: 1),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: isSelected ? palette.accentBlue : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? palette.accentBlue : palette.secondaryText.withValues(alpha: 0.6),
                        width: 2,
                      ),
                    ),
                    child: isSelected ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$optLabel.  ',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? palette.accentBlue : palette.primaryText,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      optText,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                        color: palette.bodyText,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFillBlankInput(String qId, _TakeExamPalette palette) {
    if (!_textControllers.containsKey(qId)) {
      _textControllers[qId] = TextEditingController(text: _selectedAnswers[qId]?.toString() ?? '');
    }
    final controller = _textControllers[qId]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your Answer / Calculation:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: palette.bodyText)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: TextStyle(color: palette.primaryText, fontSize: 14),
          onChanged: (val) {
            setState(() {
              if (val.trim().isNotEmpty) {
                _selectedAnswers[qId] = val;
              } else {
                _selectedAnswers.remove(qId);
              }
            });
          },
          decoration: InputDecoration(
            filled: true,
            fillColor: palette.subtleBg,
            hintText: 'Type your numerical or short response here...',
            hintStyle: TextStyle(color: palette.secondaryText, fontSize: 13.5),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: palette.borderColor)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: palette.borderColor)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: palette.accentBlue, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptiveInput(String qId, _TakeExamPalette palette) {
    if (!_textControllers.containsKey(qId)) {
      _textControllers[qId] = TextEditingController(text: _selectedAnswers[qId]?.toString() ?? '');
    }
    final controller = _textControllers[qId]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'Detailed Answer / Solution:',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: palette.bodyText),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${controller.text.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length} Words',
              style: TextStyle(fontSize: 11, color: palette.secondaryText),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: 7,
          minLines: 4,
          style: TextStyle(color: palette.primaryText, fontSize: 14),
          onChanged: (val) {
            setState(() {
              if (val.trim().isNotEmpty) {
                _selectedAnswers[qId] = val;
              } else {
                _selectedAnswers.remove(qId);
              }
            });
          },
          decoration: InputDecoration(
            filled: true,
            fillColor: palette.subtleBg,
            hintText: 'Write your comprehensive explanation, derivations, and solutions here...',
            hintStyle: TextStyle(color: palette.secondaryText, fontSize: 13.5),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: palette.borderColor)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: palette.borderColor)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: palette.accentBlue, width: 1.5)),
            contentPadding: const EdgeInsets.all(14),
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // 5. RIGHT COLUMN — PROGRESS & QUESTION NAVIGATOR (DESKTOP & TABLET)
  // ============================================================================

  Widget _buildRightProgressAndNavigator({required _TakeExamPalette palette, bool canCollapse = false}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTightHeight = constraints.maxHeight < 430;
        final progressCard = _buildProgressSummaryCard(palette: palette, canCollapse: canCollapse);
        final gridCard = _buildQuestionGridCard(palette: palette, scrollable: !isTightHeight);

        if (isTightHeight) {
          return SingleChildScrollView(
            child: Column(
              children: [
                progressCard,
                const SizedBox(height: 10),
                gridCard,
              ],
            ),
          );
        }

        return Column(
          children: [
            progressCard,
            const SizedBox(height: 10),
            Expanded(child: gridCard),
          ],
        );
      },
    );
  }

  Widget _buildProgressSummaryCard({
    required _TakeExamPalette palette,
    bool canCollapse = false,
    bool compact = false,
  }) {
    final total = _questions.length;
    final answeredCount = _answeredCount;
    final notAnsweredCount = total - answeredCount;
    final markedCount = _markedForReview.where((id) => !_isQuestionAnswered(id)).length;
    final answeredAndMarkedCount = _markedForReview.where((id) => _isQuestionAnswered(id)).length;
    final progressPct = total > 0 ? (answeredCount / total) : 0.0;

    return Container(
      padding: EdgeInsets.all(compact ? 11 : 14),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Your Progress',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: palette.primaryText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${(progressPct * 100).toInt()}%',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: palette.primaryText),
              ),
              if (canCollapse) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(Icons.last_page_rounded, size: 18, color: palette.secondaryText),
                  tooltip: 'Collapse panel',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                  onPressed: () => setState(() => _showRightNavigator = false),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$answeredCount of $total Answered',
            style: TextStyle(fontSize: 11.5, color: palette.secondaryText),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressPct,
              backgroundColor: palette.mutedBg,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 11),
          Wrap(
            spacing: 10,
            runSpacing: 6,
            children: [
              _buildLegendItem(const Color(0xFF10B981), 'Answered ($answeredCount)', palette, isFilled: true),
              _buildLegendItem(palette.secondaryText, 'Not Answered ($notAnsweredCount)', palette, isFilled: false),
              _buildLegendItem(const Color(0xFFF59E0B), 'Review ($markedCount)', palette, isFilled: true),
              _buildLegendItem(const Color(0xFF8B5CF6), 'Answered & Review ($answeredAndMarkedCount)', palette, isFilled: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionGridCard({
    required _TakeExamPalette palette,
    required bool scrollable,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: scrollable ? MainAxisSize.max : MainAxisSize.min,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isVeryNarrow = constraints.maxWidth < 240;
              if (isVeryNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Question Grid',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: palette.primaryText),
                    ),
                    const SizedBox(height: 6),
                    _buildSectionFilterDropdown(palette: palette),
                  ],
                );
              }
              return Row(
                children: [
                  Text(
                    'Question Grid',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: palette.primaryText),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSectionFilterDropdown(palette: palette),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          if (scrollable)
            Expanded(
              child: SingleChildScrollView(
                child: _buildQuestionNumberedGrid(palette),
              ),
            )
          else
            _buildQuestionNumberedGrid(palette),
        ],
      ),
    );
  }

  Widget _buildSectionFilterDropdown({
    required _TakeExamPalette palette,
    VoidCallback? onAfterChange,
  }) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: palette.subtleBg,
        border: Border.all(color: palette.borderColor),
        borderRadius: BorderRadius.circular(6),
      ),
      child: DropdownButtonHideUnderline(
        child: AppSearchableDropdown<String>.fromMenuItems(
          value: _safeSectionFilter,
          isExpanded: true,
          isDense: true,
          dropdownColor: palette.cardBg,
          icon: Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: palette.secondaryText),
          style: TextStyle(fontSize: 11.5, color: palette.bodyText, fontWeight: FontWeight.w500),
          selectedItemBuilder: (ctx) => [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'All Sections',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: palette.bodyText),
              ),
            ),
            ..._sections.map(
              (s) => Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  s['name']?.toString() ?? 'Section',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: palette.bodyText),
                ),
              ),
            ),
          ],
          items: [
            DropdownMenuItem<String>(
              value: 'All',
              child: Text(
                'All Sections',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.5, color: palette.bodyText),
              ),
            ),
            ..._sections.map(
              (s) => DropdownMenuItem<String>(
                value: s['id']?.toString() ?? '',
                child: Text(
                  s['name']?.toString() ?? 'Section',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: palette.bodyText),
                ),
              ),
            ),
          ],
          onChanged: (val) {
            if (val != null) {
              setState(() => _activeSectionFilter = val);
              onAfterChange?.call();
            }
          },
        ),
      ),
    );
  }

  // Tablet Combined Side Panel with Tabs (Questions Grid & Sections)
  Widget _buildTabletCombinedSidePanel(_TakeExamPalette palette) {
    return DefaultTabController(
      length: 2,
      child: Container(
        decoration: BoxDecoration(
          color: palette.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: palette.borderColor),
        ),
        child: Column(
          children: [
            TabBar(
              labelColor: palette.accentBlue,
              unselectedLabelColor: palette.secondaryText,
              indicatorColor: palette.accentBlue,
              dividerColor: palette.borderColor,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              tabs: const [
                Tab(icon: Icon(Icons.grid_view_rounded, size: 16), text: 'Questions'),
                Tab(icon: Icon(Icons.list_alt_rounded, size: 16), text: 'Sections'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // Tab 1: Progress + Section Filter + Scrollable Grid
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProgressSummaryCard(palette: palette, compact: true),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Text(
                              'Grid',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: palette.primaryText),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: _buildSectionFilterDropdown(palette: palette)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: SingleChildScrollView(
                            child: _buildQuestionNumberedGrid(palette),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tab 2: Sections List
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: _buildLeftSectionPalette(palette: palette, canCollapse: false),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, _TakeExamPalette palette, {required bool isFilled}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: isFilled ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: color, width: 1.5),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(fontSize: 10.5, color: palette.secondaryText),
        ),
      ],
    );
  }

  Widget _buildQuestionNumberedGrid(_TakeExamPalette palette, {VoidCallback? onItemTap}) {
    final filterId = _safeSectionFilter;
    List<Map<String, dynamic>> filteredQuestions = _questions;
    if (filterId != 'All') {
      filteredQuestions = _questions.where((q) => q['section_id']?.toString() == filterId).toList();
    }

    if (filteredQuestions.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('No questions found.', style: TextStyle(fontSize: 12, color: palette.secondaryText)),
        ),
      );
    }

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: List.generate(filteredQuestions.length, (i) {
        final q = filteredQuestions[i];
        final globalIndex = _questions.indexOf(q);
        final qId = q['id']?.toString() ?? 'q_$globalIndex';
        final isCurrent = globalIndex == _currentQuestionIndex;
        final hasAnswer = _isQuestionAnswered(qId);
        final isMarked = _markedForReview.contains(qId);

        Color bgColor = palette.subtleBg;
        Color textColor = palette.bodyText;
        Border border = Border.all(color: palette.borderColor);

        if (hasAnswer && isMarked) {
          bgColor = const Color(0xFF8B5CF6);
          textColor = Colors.white;
          border = Border.all(color: const Color(0xFF8B5CF6));
        } else if (hasAnswer) {
          bgColor = const Color(0xFF10B981);
          textColor = Colors.white;
          border = Border.all(color: const Color(0xFF10B981));
        } else if (isMarked) {
          bgColor = const Color(0xFFF59E0B);
          textColor = Colors.white;
          border = Border.all(color: const Color(0xFFF59E0B));
        } else if (isCurrent) {
          bgColor = palette.accentBlueSoft;
          textColor = palette.accentBlue;
          border = Border.all(color: palette.accentBlue, width: 2);
        }

        return InkWell(
          onTap: () {
            _navigateToQuestion(globalIndex);
            onItemTap?.call();
          },
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 39,
            height: 37,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(6),
              border: border,
              boxShadow: isCurrent && (hasAnswer || isMarked)
                  ? [BoxShadow(color: palette.accentBlue.withValues(alpha: 0.45), blurRadius: 0, spreadRadius: 1.5)]
                  : null,
            ),
            child: Center(
              child: Text(
                '${globalIndex + 1}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: (isCurrent || hasAnswer) ? FontWeight.bold : FontWeight.w500,
                  color: textColor,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  // ============================================================================
  // 6. STICKY BOTTOM ACTION BAR (ALL-DEVICE FRIENDLY, ZERO OVERFLOW DOWN TO 280PX)
  // ============================================================================

  Widget _buildStickyBottomBar(double maxWidth, bool isMobile, _TakeExamPalette palette) {
    final isUltraNarrow = maxWidth < 400;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: isUltraNarrow ? 8 : (isMobile ? 10 : 18), vertical: isMobile ? 8 : 10),
      decoration: BoxDecoration(
        color: palette.cardBg,
        border: Border(top: BorderSide(color: palette.borderColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: palette.isDark ? 0.22 : 0.04),
            blurRadius: 6,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Left: Save & Exit
          if (isUltraNarrow)
            IconButton(
              onPressed: () => _showSaveAndExitDialog(),
              tooltip: 'Save & Exit',
              icon: Icon(Icons.exit_to_app_rounded, size: 18, color: palette.bodyText),
              style: IconButton.styleFrom(
                side: BorderSide(color: palette.borderColor),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            )
          else
            OutlinedButton.icon(
              onPressed: () => _showSaveAndExitDialog(),
              icon: Icon(Icons.exit_to_app_rounded, size: 15, color: palette.bodyText),
              label: Text(
                isMobile ? 'Exit' : 'Save & Exit',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: palette.bodyText, fontWeight: FontWeight.w600, fontSize: 12.5),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: palette.borderColor),
                padding: EdgeInsets.symmetric(horizontal: isMobile ? 10 : 14, vertical: 10),
                minimumSize: const Size(0, 38),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),

          const SizedBox(width: 6),

          // Center: Prev / Next
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: OutlinedButton(
                    onPressed: _currentQuestionIndex > 0 ? () => _navigateToQuestion(_currentQuestionIndex - 1) : null,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: isUltraNarrow ? 8 : (isMobile ? 11 : 18), vertical: 10),
                      minimumSize: const Size(0, 38),
                      side: BorderSide(
                        color: _currentQuestionIndex > 0 ? palette.accentBlue : palette.borderColor,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      isMobile ? '< Prev' : '< Previous',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _currentQuestionIndex > 0 ? palette.accentBlue : palette.secondaryText,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: ElevatedButton(
                    onPressed: _currentQuestionIndex < _questions.length - 1
                        ? () => _navigateToQuestion(_currentQuestionIndex + 1)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      disabledBackgroundColor: palette.mutedBg,
                      padding: EdgeInsets.symmetric(horizontal: isUltraNarrow ? 10 : (isMobile ? 14 : 22), vertical: 10),
                      minimumSize: const Size(0, 38),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      'Next >',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _currentQuestionIndex < _questions.length - 1 ? Colors.white : palette.secondaryText,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 6),

          // Right: Submit Exam
          ElevatedButton.icon(
            onPressed: (_isSubmitting || _questions.isEmpty) ? null : () => _showSubmitConfirmationDialog(),
            icon: _isSubmitting
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded, size: 15, color: Colors.white),
            label: Text(
              _isSubmitting ? (isMobile ? 'Sending...' : 'Submitting...') : 'Submit',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 12.5),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D4ED8),
              padding: EdgeInsets.symmetric(horizontal: isUltraNarrow ? 10 : (isMobile ? 12 : 20), vertical: 10),
              minimumSize: const Size(0, 38),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // MOBILE BOTTOM SHEETS FOR SECTIONS & NAVIGATOR
  // ============================================================================

  void _openMobileSectionsSheet(_TakeExamPalette palette) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.list_alt_rounded, color: palette.accentBlue, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Select Section',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: palette.primaryText),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: palette.secondaryText),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _sections.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, index) {
                      final sec = _sections[index];
                      final secId = sec['id']?.toString() ?? 'sec-$index';
                      final secName = sec['name']?.toString() ?? 'Section ${String.fromCharCode(65 + index)}';
                      final isSelected = _expandedPaletteSectionId == secId;
                      final secQuestions = _questions.where((q) => q['section_id']?.toString() == secId).toList();

                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(color: isSelected ? palette.accentBlue : palette.borderColor),
                        ),
                        tileColor: isSelected ? palette.accentBlueSoft : palette.subtleBg,
                        title: Text(
                          secName,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? palette.accentBlue : palette.primaryText,
                          ),
                        ),
                        trailing: Text(
                          '${secQuestions.length} Qs',
                          style: TextStyle(fontSize: 12, color: palette.secondaryText),
                        ),
                        onTap: () {
                          setState(() => _expandedPaletteSectionId = secId);
                          Navigator.of(ctx).pop();
                          if (secQuestions.isNotEmpty) {
                            _navigateToQuestion(_questions.indexOf(secQuestions.first));
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openMobileNavigatorSheet(_TakeExamPalette palette) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: palette.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, setModalState) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.82),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.grid_view_rounded, color: palette.accentBlue, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Question Palette',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: palette.primaryText),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: palette.secondaryText),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildProgressSummaryCard(palette: palette, compact: true),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text(
                        'Filter Section:',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: palette.bodyText),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildSectionFilterDropdown(
                          palette: palette,
                          onAfterChange: () => setModalState(() {}),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: SingleChildScrollView(
                      child: _buildQuestionNumberedGrid(
                        palette,
                        onItemTap: () => Navigator.of(ctx).pop(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // POST-SUBMIT SUCCESS VIEW
  // ============================================================================

  Widget _buildSubmittedView(_TakeExamPalette palette) {
    final title = _examData['title'] ?? 'Examination';
    final candidateName = _candidateData['name'] ?? 'Candidate';
    final summary = _submissionSummary ?? {};
    final score = summary['score'];
    final isPass = summary['is_pass'];
    final answeredCount = summary['answered_count'] ?? _answeredCount;
    final totalQ = _questions.length;

    return Scaffold(
      backgroundColor: palette.scaffoldBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  color: palette.cardBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: palette.borderColor),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: palette.isDark ? 0.24 : 0.05),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: palette.greenBg,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.check_circle_rounded, color: palette.greenText, size: 36),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Exam Submitted Successfully!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: palette.primaryText),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Thank you, $candidateName. Your attempt for "$title" has been securely recorded.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: palette.secondaryText, height: 1.45),
                    ),
                    const SizedBox(height: 20),

                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: palette.subtleBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: palette.borderColor),
                      ),
                      child: Column(
                        children: [
                          _buildSummaryRow('Questions Answered:', '$answeredCount of $totalQ', palette.primaryText, palette),
                          const SizedBox(height: 8),
                          if (score != null) ...[
                            _buildSummaryRow('Marks Obtained:', '$score', palette.accentBlue, palette, isBold: true),
                            const SizedBox(height: 8),
                            _buildSummaryRow(
                              'Result Status:',
                              isPass == true ? 'PASSED' : 'NOT QUALIFIED',
                              isPass == true ? palette.greenText : palette.redText,
                              palette,
                              isBold: true,
                            ),
                          ] else ...[
                            _buildSummaryRow('Evaluation Status:', 'Under Teacher Evaluation', palette.amberText, palette, isBold: true),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    ElevatedButton.icon(
                      onPressed: () => safeGoBack(context),
                      icon: const Icon(Icons.arrow_back_rounded, size: 16, color: Colors.white),
                      label: const Text('Back to Examinations', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // DIALOGS: SAVE & EXIT, INSTRUCTIONS
  // ============================================================================

  void _showSaveAndExitDialog() {
    final palette = _TakeExamPalette.of(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: palette.borderColor),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: Text(
          'Save & Exit Examination?',
          style: TextStyle(color: palette.primaryText, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(
            'Your current answers will be saved. You can resume this examination later if time permits.',
            style: TextStyle(fontSize: 13.5, color: palette.secondaryText, height: 1.45),
          ),
        ),
        actions: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('Stay in Exam', style: TextStyle(color: palette.secondaryText)),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await _performAutosave();
                  _sendWsTelemetry({
                    ..._currentTelemetryMap(),
                    'event': 'candidate_exited',
                    'event_type': 'exam_exit',
                    'title': 'Candidate saved and exited examination',
                    'severity': 'low',
                  });
                  await _disposeLivekit();
                  try {
                    await _wsChannel?.sink.close();
                  } catch (_) {}
                  if (mounted) safeGoBack(context);
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                child: const Text('Save & Exit', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showInstructionsDialog() {
    final palette = _TakeExamPalette.of(context);
    final instructions = _examData['instructions']?.toString() ??
        '1. All questions are compulsory.\n2. Do not switch tabs or exit fullscreen.\n3. Autosave is active.';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: palette.cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: palette.borderColor),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        title: Row(
          children: [
            Icon(Icons.info_outline_rounded, color: palette.accentBlue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Examination Instructions',
                style: TextStyle(color: palette.primaryText, fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            child: Text(
              instructions,
              style: TextStyle(fontSize: 13.5, height: 1.55, color: palette.bodyText),
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
            child: const Text('Got it', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _TakeExamPalette {
  final bool isDark;
  const _TakeExamPalette(this.isDark);

  factory _TakeExamPalette.of(BuildContext context) {
    return _TakeExamPalette(Theme.of(context).brightness == Brightness.dark);
  }

  Color get scaffoldBg => isDark ? const Color(0xFF0A1022) : const Color(0xFFF1F5F9);
  Color get cardBg => isDark ? const Color(0xFF131D38) : Colors.white;
  Color get subtleBg => isDark ? const Color(0xFF0E172E) : const Color(0xFFF8FAFC);
  Color get mutedBg => isDark ? const Color(0xFF1A2747) : const Color(0xFFE2E8F0);
  Color get borderColor => isDark ? const Color(0xFF233258) : const Color(0xFFE2E8F0);
  Color get dividerColor => isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);

  Color get primaryText => isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
  Color get bodyText => isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B);
  Color get secondaryText => isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

  Color get accentBlue => isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
  Color get accentBlueSoft => isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.35) : const Color(0xFFEFF6FF);
  Color get accentBlueBorder => isDark ? const Color(0xFF3B82F6).withValues(alpha: 0.45) : const Color(0xFFDBEAFE);

  Color get greenText => isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
  Color get greenBg => isDark ? const Color(0xFF064E3B).withValues(alpha: 0.45) : const Color(0xFFDCFCE7);

  Color get amberText => isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
  Color get amberBg => isDark ? const Color(0xFF78350F).withValues(alpha: 0.4) : const Color(0xFFFFFBEB);

  Color get redText => isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
  Color get redBg => isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.45) : const Color(0xFFFEF2F2);
}
