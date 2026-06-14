import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/utils/l10n.dart';
import 'package:edu_shamiit_ai/core/services/student_api_service.dart';
import 'package:edu_shamiit_ai/core/utils/web_proctor_helper.dart';

class LiveExamTakingScreen extends ConsumerStatefulWidget {
  final String examId;
  final String? passcode;
  const LiveExamTakingScreen({super.key, required this.examId, this.passcode});

  @override
  ConsumerState<LiveExamTakingScreen> createState() => _LiveExamTakingScreenState();
}

class _LiveExamTakingScreenState extends ConsumerState<LiveExamTakingScreen> with WidgetsBindingObserver {
  // LiveKit Proctor Stream State
  LocalVideoTrack? _cameraTrack;
  LocalAudioTrack? _micTrack;
  LocalVideoTrack? _screenTrack;
  Room? _proctorRoom;
  bool _proctorStreamsInitialized = false;
  bool _isInitializingStreams = false;
  String? _proctorStreamsError;
  RealtimeChannel? _proctorSignalingChannel;
  int _pausedSecondsOffset = 0;
  String? _sessionId;
  DateTime? _sessionStartedAt;
  List<dynamic> _proctorLogs = [];

  // Timer settings
  late Timer _examTimer;
  int _elapsedSeconds = 0;
  int _secondsRemaining = 90 * 60;
  int _baseDurationMinutes = 90;
  late Timer _autoSaveTimer;
  bool _showAutoSavedText = false;
  Timer? _proctorSyncTimer;

  // Active state
  int _currentQuestionIndex = 0;
  final Map<int, dynamic> _studentAnswers = {}; // Index -> String/List or Map (subjective)
  final Map<int, bool> _markedForReview = {};
  final Map<int, TextEditingController> _questionControllers = {};
  
  // Proctoring warnings count
  int _warningCount = 0;
  final int _maxWarnings = 3;

  // Proctor dynamic flags
  bool _isPaused = false;
  int _extraMinutes = 0;
  String? _teacherMessage;

  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _questions = [];
  Map<String, dynamic>? _examData;
  final StudentApiService _apiService = StudentApiService();
  
  // File Upload State
  bool _isUploadingFile = false;

  // Notifications
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initNotifications();
    _loadExamData();
    registerWebFocusListener(() {
      if (mounted) {
        _triggerCheatingWarning();
      }
    });
  }

  Future<void> _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    try {
      await _localNotifications.initialize(initializationSettings);
    } catch (_) {}
  }

  Future<void> _showNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics = AndroidNotificationDetails(
      'proctor_alerts',
      'Proctor Alerts',
      channelDescription: 'Alerts sent by the AI proctoring system',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(android: androidPlatformChannelSpecifics);
    try {
      await _localNotifications.show(101, title, body, platformChannelSpecifics);
    } catch (_) {}
  }

  Future<void> _loadExamData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await _apiService.startOnlineExamSession(widget.examId, passcode: widget.passcode);
      final response = await _apiService.getOnlineExamDetails(widget.examId);
      final exam = response['data']['exam'] as Map<String, dynamic>;
      final questionsList = (response['data']['questions'] as List)
          .map((q) => Map<String, dynamic>.from(q as Map))
          .toList();
      
      final mappedQuestions = questionsList.map((q) {
        String uiType = q['question_type'] ?? 'mcq';
        if (uiType == 'fill_in_the_blank') uiType = 'fill_blank';
        if (uiType == 'assertion_reason') uiType = 'mcq';
        
        List<String> options = [];
        if (q['options'] != null) {
          options = List<String>.from(q['options'] as List);
        }
        
        return {
          'id': q['id'],
          'type': uiType,
          'q': q['question_text'] ?? '',
          'options': options,
          'marks': q['marks'] ?? 1,
        };
      }).toList();

      final session = response['data']['session'] as Map<String, dynamic>?;
      final submission = response['data']['submission'] as Map<String, dynamic>?;
      final Map<String, dynamic> savedAnswers = (submission != null && submission['answers'] != null)
          ? Map<String, dynamic>.from(submission['answers'] as Map)
          : {};

      // Initialize Text Controllers and restore saved answers
      for (int i = 0; i < mappedQuestions.length; i++) {
        final q = mappedQuestions[i];
        final qId = q['id']?.toString();
        final qType = q['type'] as String;
        
        if (qType == 'fill_blank' || qType == 'numerical' || qType == 'subjective') {
          _questionControllers[i] = TextEditingController();
        }
        
        if (qId != null && savedAnswers.containsKey(qId)) {
          final savedAns = savedAnswers[qId];
          if (qType == 'subjective') {
            if (savedAns is Map) {
              _studentAnswers[i] = Map<String, dynamic>.from(savedAns);
              _questionControllers[i]!.text = savedAns['text'] ?? '';
            } else {
              _studentAnswers[i] = {'text': savedAns?.toString() ?? ''};
              _questionControllers[i]!.text = savedAns?.toString() ?? '';
            }
          } else if (qType == 'fill_blank' || qType == 'numerical') {
            _studentAnswers[i] = savedAns;
            _questionControllers[i]!.text = savedAns?.toString() ?? '';
          } else if (qType == 'multi_correct') {
            if (savedAns is List) {
              _studentAnswers[i] = List<String>.from(savedAns.map((e) => e.toString()));
            } else if (savedAns is String) {
              _studentAnswers[i] = savedAns.split(', ').where((s) => s.isNotEmpty).toList();
            } else {
              _studentAnswers[i] = savedAns;
            }
          } else {
            _studentAnswers[i] = savedAns;
          }
        }
      }
      
      if (mounted) {
        setState(() {
          _examData = exam;
          _questions = mappedQuestions;
          _baseDurationMinutes = exam['duration_minutes'] as int? ?? 90;
          
          if (session != null) {
            _sessionId = session['id']?.toString();
            _isPaused = session['is_paused'] as bool? ?? false;
            _extraMinutes = session['extra_minutes'] as int? ?? 0;
            _warningCount = session['warnings_count'] as int? ?? 0;
            _teacherMessage = session['teacher_message'] as String?;
            _proctorLogs = session['proctor_logs'] as List<dynamic>? ?? [];
            final startedAtStr = session['started_at'] as String?;
            if (startedAtStr != null) {
              try {
                _sessionStartedAt = DateTime.parse(startedAtStr).toUtc();
              } catch (_) {}
            }
          }
          _isLoading = false;
        });

        if (session != null && session['status'] == 'suspended') {
          _showSuspensionDialog();
          return;
        }

        _updateCountdown();
        _startCountdown();
        _startAutoSave();
        _proctorSyncTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
          await _syncProctorSession();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _cleanupProctorStreams();
    _examTimer.cancel();
    _autoSaveTimer.cancel();
    _proctorSyncTimer?.cancel();
    _questionControllers.values.forEach((controller) => controller.dispose());
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Detect focus loss
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_proctorStreamsInitialized || _isInitializingStreams) return;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _triggerCheatingWarning();
    }
  }

  void _updateCountdown() {
    if (_examData == null || _sessionStartedAt == null) return;

    final now = DateTime.now().toUtc();
    final startTimeStr = _examData!['start_time'] as String?;
    if (startTimeStr == null) return;
    final scheduledStartTime = DateTime.parse(startTimeStr).toUtc();

    // 1. Calculate late seconds penalty
    int lateSeconds = 0;
    if (_sessionStartedAt!.isAfter(scheduledStartTime)) {
      lateSeconds = _sessionStartedAt!.difference(scheduledStartTime).inSeconds;
    }

    // 2. Calculate accumulated pause duration from logs
    int totalPausedSeconds = 0;
    DateTime? lastPauseTime;

    for (var log in _proctorLogs) {
      if (log is Map) {
        if (log.containsKey('paused_at_iso')) {
          try {
            lastPauseTime = DateTime.parse(log['paused_at_iso'].toString()).toUtc();
          } catch (_) {}
        } else if (log.containsKey('resumed_at_iso') && lastPauseTime != null) {
          try {
            final resumeTime = DateTime.parse(log['resumed_at_iso'].toString()).toUtc();
            totalPausedSeconds += resumeTime.difference(lastPauseTime).inSeconds;
            lastPauseTime = null;
          } catch (_) {}
        }
      }
    }

    // 3. Calculate active elapsed time
    int activeElapsed = 0;
    if (_isPaused) {
      final freezeTime = lastPauseTime ?? now;
      activeElapsed = freezeTime.difference(_sessionStartedAt!).inSeconds - totalPausedSeconds;
    } else {
      activeElapsed = now.difference(_sessionStartedAt!).inSeconds - totalPausedSeconds;
    }

    if (activeElapsed < 0) activeElapsed = 0;

    // 4. Calculate remaining seconds
    final totalDurationSeconds = (_baseDurationMinutes + _extraMinutes) * 60;
    final totalElapsedSeconds = activeElapsed + lateSeconds;

    setState(() {
      _secondsRemaining = totalDurationSeconds - totalElapsedSeconds;
      if (_secondsRemaining < 0) {
        _secondsRemaining = 0;
      }
    });
  }

  Future<void> _initProctorStreams() async {
    try {
      setState(() {
        _isInitializingStreams = true;
        _proctorStreamsError = null;
      });

      // 1. Camera track
      _cameraTrack = await LocalVideoTrack.createCameraTrack(
        const CameraCaptureOptions(
          cameraPosition: CameraPosition.front,
          params: VideoParametersPresets.h540_169,
        ),
      );

      // 2. Mic track
      _micTrack = await LocalAudioTrack.create(
        const AudioCaptureOptions(
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
        ),
      );

      // 3. Screen share track
      _screenTrack = await LocalVideoTrack.createScreenShareTrack(
        const ScreenShareCaptureOptions(
          params: VideoParametersPresets.screenShareH720FPS15,
        ),
      );

      _screenTrack!.mediaStreamTrack.onEnded = () {
        if (mounted) {
          setState(() {
            _proctorStreamsInitialized = false;
            _proctorStreamsError = 'Screen sharing was stopped. Re-enable to resume your exam.';
          });
          _triggerCheatingWarning();
        }
      };

      setState(() {
        _proctorStreamsInitialized = true;
      });

      if (_sessionId != null) {
        _setupProctorSignaling(_sessionId!);
      }

      // Add a small grace period before resetting the stream initialization flag
      // to let focus settle back onto the web page.
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _isInitializingStreams = false;
          });
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializingStreams = false;
          _proctorStreamsInitialized = false;
          _proctorStreamsError = 'Required permissions not granted: $e';
        });
      }
    }
  }

  Future<void> _setupProctorSignaling(String sessionId) async {
    final channelName = 'proctor_signal_$sessionId';
    debugPrint('[ProctorSignaling] Subscribing to $channelName');

    if (_proctorSignalingChannel != null) {
      try {
        Supabase.instance.client.removeChannel(_proctorSignalingChannel!);
      } catch (_) {}
    }

    _proctorSignalingChannel = Supabase.instance.client.channel(channelName);

    _proctorSignalingChannel!
        .onBroadcast(event: 'connect_request', callback: (payload) {
          debugPrint('[ProctorSignaling] Received connect_request: $payload');
          _handleConnectRequest();
        })
        .onBroadcast(event: 'disconnect_request', callback: (payload) {
          debugPrint('[ProctorSignaling] Received disconnect_request: $payload');
          _handleDisconnectRequest();
        })
        .subscribe((status, [error]) {
          debugPrint('[ProctorSignaling] Subscribe status: $status, error: $error');
        });
  }

  Future<void> _handleConnectRequest() async {
    try {
      if (_proctorRoom != null) {
        try {
          await _proctorRoom!.disconnect();
        } catch (_) {}
        _proctorRoom = null;
      }

      final roomName = 'proctor_session_$_sessionId';
      final tokenRes = await _apiService.getLiveKitToken(
        room: roomName,
        identity: 'student_$_sessionId',
        name: 'Student',
      );

      final token = tokenRes['token'] as String;
      String sfuUrl = tokenRes['livekit_url'] ?? 'ws://localhost:7880';
      if (sfuUrl.contains('//livekit:')) {
        sfuUrl = sfuUrl.replaceAll('//livekit:', '//localhost:');
      }
      if (sfuUrl.startsWith('http://')) {
        sfuUrl = sfuUrl.replaceFirst('http://', 'ws://');
      } else if (sfuUrl.startsWith('https://')) {
        sfuUrl = sfuUrl.replaceFirst('https://', 'wss://');
      }

      debugPrint('[ProctorSignaling] Connecting to LiveKit: $sfuUrl, Room: $roomName');

      _proctorRoom = Room();
      await _proctorRoom!.connect(sfuUrl, token);

      if (_cameraTrack != null) {
        await _proctorRoom!.localParticipant!.publishVideoTrack(_cameraTrack!);
      }
      if (_micTrack != null) {
        await _proctorRoom!.localParticipant!.publishAudioTrack(_micTrack!);
      }
      if (_screenTrack != null) {
        await _proctorRoom!.localParticipant!.publishVideoTrack(_screenTrack!);
      }

      debugPrint('[ProctorSignaling] Successfully published tracks to LiveKit room');
    } catch (e) {
      debugPrint('[ProctorSignaling] Error in handle connect request: $e');
    }
  }

  Future<void> _handleDisconnectRequest() async {
    try {
      if (_proctorRoom != null) {
        await _proctorRoom!.disconnect();
        _proctorRoom = null;
        debugPrint('[ProctorSignaling] Disconnected from LiveKit room due to teacher request');
      }
    } catch (e) {
      debugPrint('[ProctorSignaling] Error disconnecting room: $e');
    }
  }

  void _cleanupProctorStreams() {
    if (_proctorRoom != null) {
      try {
        _proctorRoom!.disconnect();
      } catch (_) {}
      _proctorRoom = null;
    }
    if (_cameraTrack != null) {
      try {
        _cameraTrack!.stop();
      } catch (_) {}
      _cameraTrack = null;
    }
    if (_micTrack != null) {
      try {
        _micTrack!.stop();
      } catch (_) {}
      _micTrack = null;
    }
    if (_screenTrack != null) {
      try {
        _screenTrack!.stop();
      } catch (_) {}
      _screenTrack = null;
    }
    if (_proctorSignalingChannel != null) {
      try {
        Supabase.instance.client.removeChannel(_proctorSignalingChannel!);
      } catch (_) {}
      _proctorSignalingChannel = null;
    }
  }

  void _startCountdown() {
    _examTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateCountdown();

      if (_secondsRemaining <= 0) {
        _examTimer.cancel();
        _autoSubmitExam();
      }
    });
  }

  Future<bool> _submitAnswersToBackend() async {
    final Map<String, dynamic> answersToSend = {};
    for (int i = 0; i < _questions.length; i++) {
      final q = _questions[i];
      final qId = q['id']?.toString();
      final ans = _studentAnswers[i];
      if (ans != null && qId != null) {
        if (ans is List) {
          answersToSend[qId] = ans.join(', ');
        } else if (ans is Map) {
          answersToSend[qId] = ans;
        } else {
          answersToSend[qId] = ans.toString();
        }
      }
    }
    try {
      await _apiService.submitOnlineExamDynamic(
        examId: widget.examId,
        answers: answersToSend,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _executeFinalSubmission({bool isAuto = false}) async {
    // Show a blocker loading overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PopScope(
        canPop: false,
        child: Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Submitting your answers... Please wait.'),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Call submit
    final success = await _submitAnswersToBackend();
    
    // Close the loading dialog
    if (mounted) {
      Navigator.of(context).pop();
    }

    if (success) {
      _showNotification('Exam Submitted', isAuto ? 'Your exam answers were submitted automatically.' : 'Your exam answers have been locked and submitted.');
      if (mounted) {
        context.pushReplacement('/student/exams/submit/${widget.examId}?auto=$isAuto');
      }
    } else {
      // Show retry dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('⚠️ Submission Failed'),
            content: const Text('We could not submit your exam answers. Please check your internet connection and try again.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // close retry dialog
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // close retry dialog
                  _executeFinalSubmission(isAuto: isAuto); // retry submission
                },
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      }
    }
  }

  void _startAutoSave() {
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (_isPaused) return;
      _submitAnswersToBackend();
      
      if (mounted) {
        setState(() {
          _showAutoSavedText = true;
        });
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _showAutoSavedText = false;
            });
          }
        });
      }
    });
  }

  Future<void> _syncProctorSession() async {
    try {
      final currentQ = _questions.isNotEmpty && _currentQuestionIndex < _questions.length
          ? _questions[_currentQuestionIndex]
          : null;
      final qId = currentQ?['id']?.toString();
      
      final res = await _apiService.pingOnlineExamSession(
        widget.examId,
        warningsCount: _warningCount,
        activeQuestionId: qId,
        isOnline: true,
      );
      
      if (res['success'] == true && res['data'] != null) {
        final data = res['data'] as Map<String, dynamic>;
        final isPaused = data['is_paused'] as bool? ?? false;
        final extraMins = data['extra_minutes'] as int? ?? 0;
        final teacherMsg = data['teacher_message'] as String?;
        final status = data['status'] as String? ?? 'active';
        final serverWarnings = data['warnings_count'] as int? ?? 0;
        
        if (mounted) {
          setState(() {
            _isPaused = isPaused;
            _extraMinutes = extraMins;
            _teacherMessage = teacherMsg;
            _proctorLogs = data['proctor_logs'] as List<dynamic>? ?? [];
            final startedAtStr = data['started_at'] as String?;
            if (startedAtStr != null) {
              _sessionStartedAt = DateTime.parse(startedAtStr).toUtc();
            }
          });
          _updateCountdown();
          
          if (serverWarnings > _warningCount) {
            setState(() {
              _warningCount = serverWarnings;
            });
            if (_warningCount >= _maxWarnings) {
              _examTimer.cancel();
              _autoSaveTimer.cancel();
              _proctorSyncTimer?.cancel();
              _showNotification('⚠️ Exam Terminated', 'Limit of $_maxWarnings proctor warnings exceeded.');
              _autoSubmitExam();
            } else {
              _showNotification(
                '⚠️ Proctor Warning $_warningCount/$_maxWarnings',
                teacherMsg ?? 'You have received a warning from the proctor.'
              );
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  title: Text('⚠️ Proctor Warning $_warningCount/$_maxWarnings', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  content: Text(teacherMsg ?? 'You have received a warning from the proctor.\n\nWarning: Reaching $_maxWarnings warnings will result in auto-submission.'),
                  actions: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('I Understand'),
                    ),
                  ],
                ),
              );
            }
          }
          
          if (status == 'suspended') {
            _examTimer.cancel();
            _autoSaveTimer.cancel();
            _proctorSyncTimer?.cancel();
            _showSuspensionDialog();
          } else if (status == 'completed') {
            _examTimer.cancel();
            _autoSaveTimer.cancel();
            _proctorSyncTimer?.cancel();
            _showNotification('Exam Completed', 'Your exam session was completed.');
            context.pushReplacement('/student/exams/submit/${widget.examId}?auto=true');
          }
        }
      }
    } catch (_) {}
  }

  void _triggerCheatingWarning() async {
    if (!_proctorStreamsInitialized || _isInitializingStreams) return;
    if (_warningCount < _maxWarnings - 1) {
      setState(() {
        _warningCount++;
      });
      
      _showNotification(
        '⚠️ Proctor Warning $_warningCount/$_maxWarnings',
        'Focus loss detected! Do not switch tabs or minimize the window.'
      );
      
      await _apiService.pingOnlineExamSession(
        widget.examId,
        warningsCount: _warningCount,
        isOnline: true,
        logEvent: 'Warning issued: focus loss detected',
      );

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text('⚠️ Proctor Warning $_warningCount/$_maxWarnings', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            content: const Text('Focus loss detected! Switching tabs, minimizing windows, or taking screenshots is prohibited.\n\nWarning: Reaching 3 warnings will result in auto-submission.'),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(context),
                child: const Text('I Understand'),
              ),
            ],
          ),
        );
      }
    } else {
      setState(() {
        _warningCount = _maxWarnings;
      });
      _examTimer.cancel();
      _autoSaveTimer.cancel();
      _proctorSyncTimer?.cancel();
      try {
        await _apiService.pingOnlineExamSession(
          widget.examId,
          warningsCount: _warningCount,
          isOnline: true,
          logEvent: 'Warning limit exceeded: session terminated',
        );
      } catch (_) {}
      _autoSubmitExam();
    }
  }

  void _showSuspensionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🚨 Exam Suspended', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Text(_teacherMessage ?? 'You have been suspended from this exam by the proctor.'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/student/exams');
            },
            child: const Text('Return to Dashboard'),
          ),
        ],
      ),
    );
  }

  void _autoSubmitExam() async {
    _executeFinalSubmission(isAuto: true);
  }

  Future<void> _pickAndUploadFile() async {
    setState(() {
      _isUploadingFile = true;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
        withData: true,
      );
      
      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes;
        if (bytes != null) {
          final response = await _apiService.uploadExamAttachment(
            fileBytes: bytes,
            filename: file.name,
            contentType: 'application/octet-stream',
          );
          
          if (response['success'] == true && response['data'] != null) {
            final fileUrl = response['data']['url'] as String;
            
            final currentAns = _studentAnswers[_currentQuestionIndex];
            String textVal = '';
            if (currentAns is Map) {
              textVal = currentAns['text'] ?? '';
            } else if (currentAns is String) {
              textVal = currentAns;
            }
            
            setState(() {
              _studentAnswers[_currentQuestionIndex] = {
                'text': textVal,
                'file_url': fileUrl,
                'filename': file.name
              };
            });
            
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('File uploaded successfully!'), backgroundColor: Colors.green),
            );
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isUploadingFile = false;
      });
    }
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '00:00:00';
    final h = (seconds / 3600).floor();
    final m = ((seconds % 3600) / 60).floor();
    final s = seconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  int get _answeredCount => _studentAnswers.values.where((ans) {
        if (ans is Map) return (ans['text'] != null && ans['text'].toString().isNotEmpty) || ans['file_url'] != null;
        if (ans is List) return ans.isNotEmpty;
        if (ans is String) return ans.trim().isNotEmpty;
        return ans != null;
      }).length;

  int get _reviewCount => _markedForReview.values.where((v) => v).length;

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF134E4A)),
        ),
      );
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Error: $_error', style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadExamData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (_questions.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text('No questions found for this exam.'),
        ),
      );
    }

    if (!_proctorStreamsInitialized) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(32),
            child: Card(
              color: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: Color(0xFF334155)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.security, size: 64, color: Colors.blueAccent),
                    const SizedBox(height: 24),
                    const Text(
                      'Secure Proctoring Setup',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        fontFamily: AppFonts.heading,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _proctorStreamsError ??
                          'To ensure exam integrity, please share your screen, microphone, and webcam. You must share your entire screen/application window to begin.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.videocam, color: Colors.white),
                      label: const Text('Begin Exam Session', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _initProctorStreams,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    final question = _questions[_currentQuestionIndex];
    final isTimerCritical = _secondsRemaining < 300;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _showExitWarning();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF1F5F9),
        body: SafeArea(
          child: Column(
            children: [
              // Top Bar
              _buildTopBar(isTimerCritical),

              // Main working area
              Expanded(
                child: Stack(
                  children: [
                    Row(
                      children: [
                        // Question Workspace
                        Expanded(
                          flex: 3,
                          child: _buildQuestionWorkspace(question),
                        ),

                        // Collapsible Desktop Sidebar Palette
                        MediaQuery.of(context).size.width > 700
                            ? Container(
                                width: 220,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  border: Border(left: BorderSide(color: StudentColors.border)),
                                ),
                                child: _buildQuestionPalette(),
                              )
                            : const SizedBox.shrink(),
                      ],
                    ),
                    if (_isPaused)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withOpacity(0.85),
                          child: Center(
                            child: Card(
                              margin: const EdgeInsets.all(24),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.pause_circle_filled, size: 64, color: Colors.orange),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'EXAM PAUSED BY PROCTOR',
                                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.2),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _teacherMessage ?? 'Your exam has been temporarily paused by the proctor. Please wait for further instructions.',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 14, color: Colors.black54),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Bottom control bar
              _buildBottomControlBar(),
            ],
          ),
        ),
        drawer: MediaQuery.of(context).size.width <= 700
            ? Drawer(
                child: SafeArea(child: _buildQuestionPalette()),
              )
            : null,
      ),
    );
  }

  Widget _buildTopBar(bool isCritical) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
      ),
      child: Row(
        children: [
          // Logo & Warning Level
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _examData?['title'] ?? 'Online Exam',
                style: const TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _isPaused ? Colors.orange : Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isPaused ? 'AI Proctor: Paused' : 'AI Proctor: Monitored',
                    style: const TextStyle(fontSize: 9, color: Colors.white60),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),

          // Autosaved status
          if (_showAutoSavedText)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.cloud_done_outlined, size: 12, color: Colors.greenAccent),
                  SizedBox(width: 4),
                  Text('Auto-saved', style: TextStyle(fontSize: 10, color: Colors.white70)),
                ],
              ),
            ),

          // Warnings Badge
          if (_warningCount > 0)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red),
              ),
              child: Text(
                'Warnings: $_warningCount/$_maxWarnings',
                style: const TextStyle(fontSize: 10, color: Colors.redAccent, fontWeight: FontWeight.bold),
              ),
            ),

          // Timer Countdown Widget
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isCritical ? Colors.red.withOpacity(0.2) : Colors.white10,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: isCritical ? Colors.red : Colors.white24),
            ),
            child: Row(
              children: [
                Icon(Icons.timer_outlined, size: 14, color: isCritical ? Colors.red : Colors.white),
                const SizedBox(width: 6),
                Text(
                  _formatDuration(_secondsRemaining),
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isCritical ? Colors.red : Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionWorkspace(Map<String, dynamic> question) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: StudentColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: StudentColors.primaryLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
                        style: const TextStyle(
                          color: StudentColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Text(
                      '+${question['marks']} Marks',
                      style: const TextStyle(
                        color: StudentColors.success,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  question['q']!,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: StudentColors.text,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Render Question Input
          _buildQuestionInputArea(question),
        ],
      ),
    );
  }

  Widget _buildQuestionInputArea(Map<String, dynamic> question) {
    final qType = question['type'] as String;
    final currentAns = _studentAnswers[_currentQuestionIndex];

    switch (qType) {
      case 'mcq':
        return Column(
          children: (question['options'] as List<String>).map((opt) {
            final isSelected = currentAns == opt;
            return _buildOptionRow(opt, isSelected, () {
              setState(() {
                _studentAnswers[_currentQuestionIndex] = opt;
              });
            });
          }).toList(),
        );

      case 'multi_correct':
        final selectedList = (currentAns as List<dynamic>?)?.cast<String>() ?? [];
        return Column(
          children: (question['options'] as List<String>).map((opt) {
            final isSelected = selectedList.contains(opt);
            return _buildOptionRow(opt, isSelected, () {
              setState(() {
                if (isSelected) {
                  selectedList.remove(opt);
                } else {
                  selectedList.add(opt);
                }
                _studentAnswers[_currentQuestionIndex] = selectedList;
              });
            }, isMulti: true);
          }).toList(),
        );

      case 'true_false':
        return Column(
          children: (question['options'] as List<String>).map((opt) {
            final isSelected = currentAns == opt;
            return _buildOptionRow(opt, isSelected, () {
              setState(() {
                _studentAnswers[_currentQuestionIndex] = opt;
              });
            });
          }).toList(),
        );

      case 'fill_blank':
        final controller = _questionControllers[_currentQuestionIndex]!;
        if (controller.text != (currentAns as String? ?? '')) {
          controller.text = currentAns as String? ?? '';
          controller.selection = TextSelection.fromPosition(TextPosition(offset: controller.text.length));
        }
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: StudentColors.border),
          ),
          child: TextField(
            controller: controller,
            onChanged: (text) {
              _studentAnswers[_currentQuestionIndex] = text;
            },
            decoration: InputDecoration(
              hintText: 'Type your answer...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        );

      case 'numerical':
        final controller = _questionControllers[_currentQuestionIndex]!;
        if (controller.text != (currentAns as String? ?? '')) {
          controller.text = currentAns as String? ?? '';
          controller.selection = TextSelection.fromPosition(TextPosition(offset: controller.text.length));
        }
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: StudentColors.border),
          ),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            onChanged: (text) {
              _studentAnswers[_currentQuestionIndex] = text;
            },
            decoration: InputDecoration(
              hintText: 'Enter numerical value...',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              prefixIcon: const Icon(Icons.calculate_outlined),
            ),
          ),
        );

      case 'subjective':
        String textVal = '';
        String? fileUrl;
        String? filename;
        if (currentAns is Map) {
          textVal = currentAns['text'] ?? '';
          fileUrl = currentAns['file_url'];
          filename = currentAns['filename'];
        } else if (currentAns is String) {
          textVal = currentAns;
        }

        final controller = _questionControllers[_currentQuestionIndex]!;
        if (controller.text != textVal) {
          controller.text = textVal;
          controller.selection = TextSelection.fromPosition(TextPosition(offset: controller.text.length));
        }

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: StudentColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Write your summary below:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    maxLines: 6,
                    onChanged: (val) {
                      _studentAnswers[_currentQuestionIndex] = {
                        'text': val,
                        'file_url': fileUrl,
                        'filename': filename,
                      };
                    },
                    decoration: InputDecoration(
                      hintText: 'Type your explanation summary here...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: StudentColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Attach scan files (Handwritten sheets):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  if (fileUrl != null) ...[
                    Row(
                      children: [
                        const Icon(Icons.description, color: Colors.green, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            filename ?? 'Uploaded File',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _studentAnswers[_currentQuestionIndex] = {
                                'text': textVal,
                                'file_url': null,
                                'filename': null,
                              };
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      if (_isUploadingFile)
                        const CircularProgressIndicator()
                      else
                        OutlinedButton.icon(
                          onPressed: _pickAndUploadFile,
                          icon: const Icon(Icons.upload_file_outlined, size: 16),
                          label: const Text('Upload PDF/Image'),
                          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFF134E4A)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildOptionRow(String label, bool isSelected, VoidCallback onTap, {bool isMulti = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEEF2FF) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? StudentColors.primary : StudentColors.border,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: isSelected ? StudentColors.primary : Colors.transparent,
                  shape: isMulti ? BoxShape.rectangle : BoxShape.circle,
                  borderRadius: isMulti ? BorderRadius.circular(4) : null,
                  border: Border.all(
                    color: isSelected ? StudentColors.primary : Colors.grey.shade400,
                    width: 2,
                  ),
                ),
                child: isSelected ? const Icon(Icons.check, size: 12, color: Colors.white) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? StudentColors.primary : StudentColors.text,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionPalette() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: StudentColors.border)),
          ),
          child: const Text(
            'Question Navigator',
            style: TextStyle(fontFamily: AppFonts.heading, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ),

        // Legends
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            children: [
              _buildPaletteLegend('Answered', StudentColors.success),
              const SizedBox(height: 6),
              _buildPaletteLegend('Marked Review', StudentColors.warning),
              const SizedBox(height: 6),
              _buildPaletteLegend('Skipped / Unread', const Color(0xFFE2E8F0)),
            ],
          ),
        ),
        const Divider(),

        // Grid numbers
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: _questions.length,
            itemBuilder: (context, index) {
              final isCurrent = index == _currentQuestionIndex;
              final isReview = _markedForReview[index] ?? false;
              final isAnswered = _studentAnswers[index] != null;

              Color bgColor = const Color(0xFFF1F5F9);
              Color textColor = StudentColors.text2;

              if (isCurrent) {
                bgColor = StudentColors.primary;
                textColor = Colors.white;
              } else if (isReview) {
                bgColor = StudentColors.warning;
                textColor = Colors.white;
              } else if (isAnswered) {
                bgColor = StudentColors.success;
                textColor = Colors.white;
              }

              return InkWell(
                onTap: () {
                  setState(() {
                    _currentQuestionIndex = index;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(8),
                    border: isCurrent ? Border.all(color: StudentColors.primaryDeep, width: 2) : null,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Stats summary
        Container(
          padding: const EdgeInsets.all(16),
          color: const Color(0xFFF8FAFC),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total answered:', style: TextStyle(fontSize: 11, color: StudentColors.text2)),
                  Text('$_answeredCount/${_questions.length}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Review list:', style: TextStyle(fontSize: 11, color: StudentColors.text2)),
                  Text('$_reviewCount marked', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaletteLegend(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 11, color: StudentColors.text2)),
      ],
    );
  }

  Widget _buildBottomControlBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          if (MediaQuery.of(context).size.width <= 700)
            Builder(
              builder: (context) => IconButton(
                icon: const Icon(Icons.grid_view, color: StudentColors.text2),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),

          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _markedForReview[_currentQuestionIndex] = !(_markedForReview[_currentQuestionIndex] ?? false);
              });
            },
            icon: Icon(
              _markedForReview[_currentQuestionIndex] == true ? Icons.flag : Icons.flag_outlined,
              size: 14,
              color: _markedForReview[_currentQuestionIndex] == true ? StudentColors.warning : StudentColors.text2,
            ),
            label: const Text('Review'),
            style: OutlinedButton.styleFrom(
              foregroundColor: _markedForReview[_currentQuestionIndex] == true ? StudentColors.warning : StudentColors.text2,
            ),
          ),
          const Spacer(),

          TextButton(
            onPressed: () {
              setState(() {
                _studentAnswers.remove(_currentQuestionIndex);
                if (_questionControllers.containsKey(_currentQuestionIndex)) {
                  _questionControllers[_currentQuestionIndex]!.clear();
                }
              });
            },
            child: const Text('Clear'),
          ),

          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
            onPressed: _currentQuestionIndex > 0
                ? () {
                    setState(() {
                      _currentQuestionIndex--;
                    });
                  }
                : null,
          ),

          if (_currentQuestionIndex < _questions.length - 1)
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _currentQuestionIndex++;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF134E4A),
                foregroundColor: Colors.white,
              ),
              child: const Text('Next'),
            )
          else
            ElevatedButton(
              onPressed: _showFinalSubmissionConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: StudentColors.success,
                foregroundColor: Colors.white,
              ),
              child: const Text('Submit Exam'),
            ),
        ],
      ),
    );
  }

  void _showExitWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🚨 Exit Exam?'),
        content: const Text('Exiting the exam screen now will log a proctoring violation. If you must leave, click Submit Exam instead to save progress.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _autoSubmitExam();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Exit anyway'),
          ),
        ],
      ),
    );
  }

  void _showFinalSubmissionConfirm() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Final Exam Submission'),
        content: Text('Are you sure you want to finish and submit?\n\nAnswered: $_answeredCount/${_questions.length}\nReview Marked: $_reviewCount'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: StudentColors.success, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context);
              _executeFinalSubmission(isAuto: false);
            },
            child: const Text('Yes, Submit'),
          ),
        ],
      ),
    );
  }
}
