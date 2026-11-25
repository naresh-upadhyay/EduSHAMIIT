import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:edu_shamiit_core/screens/exams/services/exams_api_service.dart';
import 'package:edu_shamiit_core/screens/exams/services/exam_prestart_handoff.dart';
import 'package:edu_shamiit_core/screens/exams/utils/exam_nav_helper.dart';

/// Dynamic, Theme-Aware & Role-Based Examination Pre-Start Screen
///
/// Features:
/// 1. Dynamic Metadata Bar pulled directly from the selected Exam in PostgreSQL.
/// 2. Full Dark Mode & Light Mode adaptive design with crisp contrast on every card.
/// 3. Real interactive hardware & permission controls:
///    - Camera (Enable/Disable, Device Selector, Live WebRTC Feed)
///    - Microphone (Enable/Disable, Device Selector, Live/Simulated Waveform)
///    - Screen Share (Real browser getDisplayMedia picker + Live Screen Preview + Stop)
///    - Device & Internet (Real latency ping RTT measurement + Viewport check)
/// 4. Exam Setter Customization Mode vs Target Candidate Read-Only Mode:
///    - Exam Setters / Admins can configure Camera/Mic/ScreenShare/Device modes
///      (Mandatory / Optional / No Need), fullscreen rules, max tab switches,
///      custom categorized Instructions (CRUD), and custom Warning rules.
///    - Students / Target Candidates have strictly read-only access to policies,
///      instructions, and warnings, with interactive permission controls.
class ExamPrestartScreen extends ConsumerStatefulWidget {
  final String? examId;
  final Map<String, dynamic>? initialSeedData;

  const ExamPrestartScreen({
    super.key,
    this.examId,
    this.initialSeedData,
  });

  @override
  ConsumerState<ExamPrestartScreen> createState() => _ExamPrestartScreenState();
}

class _ExamPrestartScreenState extends ConsumerState<ExamPrestartScreen> {
  final ExamsApiService _apiService = ExamsApiService.instance;

  bool _isLoading = true;
  String? _errorMessage;
  bool _isSavingConfig = false;
  bool _isSavingInstructions = false;

  // Backend metadata
  Map<String, dynamic> _examData = {};
  Map<String, dynamic> _candidateData = {};
  Map<String, List<Map<String, dynamic>>> _instructions = {};
  List<String> _warnings = [];
  Map<String, dynamic> _policy = {};

  // Role permissions & Setter view toggle
  bool _canCustomize = false;
  bool _isCustomizeMode = false;

  // Tri-state policies: 'REQUIRED' | 'OPTIONAL' | 'DISABLED'
  String _cameraMode = 'REQUIRED';
  String _micMode = 'REQUIRED';
  String _screenMode = 'OPTIONAL';
  String _deviceMode = 'REQUIRED';
  bool _fullscreenRequired = true;
  int _maxTabSwitches = 3;
  bool _acknowledgmentRequired = true;

  // Selected instructions tab
  String _selectedTab = 'general';

  // Interactive Check States:
  // 'pending' | 'requesting' | 'allowed' | 'denied' | 'disabled_policy'
  String _cameraStatus = 'pending';
  String _micStatus = 'pending';
  String _screenStatus = 'pending'; // 'pending' | 'requesting' | 'shared' | 'denied' | 'disabled_policy'
  String _systemStatus = 'checking'; // 'checking' | 'compatible' | 'warning'
  String? _cameraError;
  String? _micError;
  String? _screenError;
  int _latencyMs = 0;

  // Media Devices Enumeration
  List<MediaDeviceInfo> _videoDevices = [];
  List<MediaDeviceInfo> _audioDevices = [];
  String? _selectedVideoDeviceId;
  String? _selectedAudioDeviceId;

  // Candidate Acknowledgment
  bool _isAcknowledged = false;
  bool _isSubmittingAck = false;

  // WebRTC Renderers & Streams
  final RTCVideoRenderer _cameraRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _screenRenderer = RTCVideoRenderer();
  MediaStream? _cameraStream;
  MediaStream? _micStream;
  MediaStream? _screenStream;
  lk.LocalVideoTrack? _lkScreenTrack;
  bool _cameraRendererReady = false;
  bool _screenRendererReady = false;

  // Waveform animation timer (active when mic is allowed & enabled)
  Timer? _waveformTimer;
  List<double> _waveformHeights = List.filled(16, 4.0);

  @override
  void initState() {
    super.initState();
    _initRenderers();
    _loadPrestartData();
  }

  @override
  void didUpdateWidget(covariant ExamPrestartScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.examId != widget.examId) {
      _stopAllStreams();
      _cameraStatus = 'pending';
      _micStatus = 'pending';
      _screenStatus = 'pending';
      _isAcknowledged = false;
      _loadPrestartData();
    }
  }

  Future<void> _initRenderers() async {
    try {
      await _cameraRenderer.initialize();
      _cameraRendererReady = true;
    } catch (e) {
      debugPrint('[Prestart] Camera renderer init error: $e');
    }
    try {
      await _screenRenderer.initialize();
      _screenRendererReady = true;
    } catch (e) {
      debugPrint('[Prestart] Screen renderer init error: $e');
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _waveformTimer?.cancel();
    _stopCameraStream();
    _stopMicStream();
    if (_screenStream != null) {
      _stopScreenStream();
    }
    try {
      if (_cameraRendererReady) _cameraRenderer.dispose();
    } catch (_) {}
    try {
      if (_screenRendererReady) _screenRenderer.dispose();
    } catch (_) {}
    super.dispose();
  }

  void _stopCameraStream() {
    if (_cameraStream != null) {
      for (var t in _cameraStream!.getTracks()) {
        try {
          t.stop();
        } catch (_) {}
      }
      _cameraStream = null;
    }
    try {
      _cameraRenderer.srcObject = null;
    } catch (_) {}
  }

  void _stopMicStream() {
    _waveformTimer?.cancel();
    if (_micStream != null) {
      for (var t in _micStream!.getTracks()) {
        try {
          t.stop();
        } catch (_) {}
      }
      _micStream = null;
    }
    _waveformHeights = List.filled(16, 4.0);
  }

  void _stopScreenStream() {
    if (_lkScreenTrack != null) {
      try {
        _lkScreenTrack!.stop();
        _lkScreenTrack!.dispose();
      } catch (_) {}
      _lkScreenTrack = null;
    }
    if (_screenStream != null) {
      for (var t in _screenStream!.getTracks()) {
        try {
          t.stop();
        } catch (_) {}
      }
      _screenStream = null;
    }
    try {
      _screenRenderer.srcObject = null;
    } catch (_) {}
  }

  void _stopAllStreams() {
    _stopCameraStream();
    _stopMicStream();
    _stopScreenStream();
  }

  void _startWaveformPulse() {
    _waveformTimer?.cancel();
    final rand = Random();
    _waveformTimer = Timer.periodic(const Duration(milliseconds: 110), (_) {
      if (mounted && _micStatus == 'allowed') {
        setState(() {
          _waveformHeights = List.generate(16, (_) => 6.0 + rand.nextDouble() * 34.0);
        });
      }
    });
  }

  Map<String, dynamic> _asMap(dynamic val) {
    if (val is Map<String, dynamic>) return val;
    if (val is Map) return Map<String, dynamic>.from(val);
    return {};
  }

  Future<void> _loadPrestartData() async {
    final examId = widget.examId ?? '';
    if (examId.isEmpty && widget.initialSeedData == null) {
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
      final Map<String, dynamic> data;
      if (widget.initialSeedData != null) {
        data = widget.initialSeedData!;
      } else {
        // getExamPrestartInfo already unwraps `data` from API response
        data = await _apiService.getExamPrestartInfo(examId);
      }

      if (data.containsKey('_error')) {
        throw Exception(data['_error']);
      }

      _examData = _asMap(data['exam']);
      _candidateData = _asMap(data['candidate']);
      final permissions = _asMap(data['permissions']);
      _canCustomize = permissions['can_customize'] == true;

      _policy = _asMap(data['readiness_policy']);
      _cameraMode = (_policy['camera_mode'] ?? (_policy['camera_required'] == true ? 'REQUIRED' : 'OPTIONAL')).toString().toUpperCase();
      _micMode = (_policy['microphone_mode'] ?? (_policy['microphone_required'] == true ? 'REQUIRED' : 'OPTIONAL')).toString().toUpperCase();
      _screenMode = (_policy['screen_share_mode'] ?? (_policy['screen_sharing_required'] == true ? 'REQUIRED' : 'OPTIONAL')).toString().toUpperCase();
      _deviceMode = (_policy['device_check_mode'] ?? 'REQUIRED').toString().toUpperCase();
      _fullscreenRequired = _policy['fullscreen_required'] ?? true;
      _maxTabSwitches = int.tryParse((_policy['max_tab_switches'] ?? 3).toString()) ?? 3;
      _acknowledgmentRequired = _policy['instruction_acknowledgment_required'] ?? true;

      // Parse instructions by category
      final rawInstructions = _asMap(data['instructions']);
      final Map<String, List<Map<String, dynamic>>> parsedInst = {};
      for (var entry in rawInstructions.entries) {
        if (entry.value is List) {
          parsedInst[entry.key] = (entry.value as List)
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList();
        }
      }
      _instructions = parsedInst;

      // Parse warnings
      if (data['warnings'] is List) {
        _warnings = (data['warnings'] as List).map((w) => w.toString()).toList();
      }

      // Restore previous acknowledgment state if saved
      final prestartSession = _asMap(data['prestart_session']);
      if (prestartSession['acknowledged'] == true) {
        _isAcknowledged = true;
      }

      // Initialize device status cleanly based on policy
      _applyPolicyToStatuses();

      // Run initial non-blocking network check & enumerate devices
      if (widget.initialSeedData != null) {
        _latencyMs = 45;
        _systemStatus = 'compatible';
      } else {
        await _runDeviceAndNetworkCheck();
        await _enumerateDevices();
      }
    } catch (e) {
      debugPrint('[Prestart] Error loading prestart data: $e');
      setState(() {
        _errorMessage = 'Could not load examination configuration: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _applyPolicyToStatuses() {
    if (_cameraMode == 'DISABLED') {
      _stopCameraStream();
      _cameraStatus = 'disabled_policy';
    } else if (_cameraStatus == 'disabled_policy') {
      _cameraStatus = 'pending';
    }

    if (_micMode == 'DISABLED') {
      _stopMicStream();
      _micStatus = 'disabled_policy';
    } else if (_micStatus == 'disabled_policy') {
      _micStatus = 'pending';
    }

    if (_screenMode == 'DISABLED') {
      _stopScreenStream();
      _screenStatus = 'disabled_policy';
    } else if (_screenStatus == 'disabled_policy') {
      _screenStatus = 'pending';
    }
  }

  Future<void> _enumerateDevices() async {
    try {
      final devices = await navigator.mediaDevices.enumerateDevices();
      if (!mounted) return;
      setState(() {
        _videoDevices = devices.where((d) => d.kind == 'videoinput').toList();
        _audioDevices = devices.where((d) => d.kind == 'audioinput').toList();
        if (_videoDevices.isNotEmpty && _selectedVideoDeviceId == null) {
          _selectedVideoDeviceId = _videoDevices.first.deviceId;
        }
        if (_audioDevices.isNotEmpty && _selectedAudioDeviceId == null) {
          _selectedAudioDeviceId = _audioDevices.first.deviceId;
        }
      });
    } catch (e) {
      debugPrint('[Prestart] Device enumeration error: $e');
    }
  }

  // --- INTERACTIVE HARDWARE CHECK HANDLERS ---

  Future<void> _requestCameraAccess({String? deviceId}) async {
    if (_cameraMode == 'DISABLED') return;
    setState(() {
      _cameraStatus = 'requesting';
      _cameraError = null;
    });
    _stopCameraStream();

    try {
      final videoConstraints = <String, dynamic>{
        'width': {'ideal': 640},
        'height': {'ideal': 480},
      };
      if (deviceId != null && deviceId.isNotEmpty) {
        videoConstraints['deviceId'] = {'exact': deviceId};
      } else {
        videoConstraints['facingMode'] = 'user';
      }

      _cameraStream = await navigator.mediaDevices.getUserMedia({
        'video': videoConstraints,
        'audio': false,
      });
      if (_cameraRendererReady) {
        _cameraRenderer.srcObject = _cameraStream;
      }
      await _enumerateDevices();
      if (mounted) {
        setState(() {
          _cameraStatus = 'allowed';
          if (deviceId != null) _selectedVideoDeviceId = deviceId;
        });
      }
      _syncChecksToBackend();
    } catch (e) {
      debugPrint('[Prestart] Camera permission error: $e');
      if (mounted) {
        setState(() {
          _cameraStatus = 'denied';
          _cameraError = 'Camera access denied or device not found.';
        });
      }
      _syncChecksToBackend();
    }
  }

  void _disableCameraByUser() {
    _stopCameraStream();
    setState(() {
      _cameraStatus = 'pending';
      _cameraError = null;
    });
    _syncChecksToBackend();
  }

  Future<void> _requestMicAccess({String? deviceId}) async {
    if (_micMode == 'DISABLED') return;
    setState(() {
      _micStatus = 'requesting';
      _micError = null;
    });
    _stopMicStream();

    try {
      final audioConstraints = (deviceId != null && deviceId.isNotEmpty)
          ? <String, dynamic>{'deviceId': {'exact': deviceId}}
          : true;

      _micStream = await navigator.mediaDevices.getUserMedia({
        'audio': audioConstraints,
        'video': false,
      });

      final tracks = _micStream?.getAudioTracks() ?? [];
      if (tracks.isEmpty) {
        throw Exception('No active microphone audio track detected.');
      }

      await _enumerateDevices();
      if (mounted) {
        setState(() {
          _micStatus = 'allowed';
          if (deviceId != null) _selectedAudioDeviceId = deviceId;
        });
        _startWaveformPulse();
      }
      _syncChecksToBackend();
    } catch (e) {
      debugPrint('[Prestart] Microphone permission error: $e');
      if (mounted) {
        setState(() {
          _micStatus = 'denied';
          _micError = 'Microphone access denied or unavailable.';
        });
      }
      _syncChecksToBackend();
    }
  }

  void _disableMicByUser() {
    _stopMicStream();
    setState(() {
      _micStatus = 'pending';
      _micError = null;
    });
    _syncChecksToBackend();
  }

  Future<void> _requestScreenShare() async {
    if (_screenMode == 'DISABLED') return;
    setState(() {
      _screenStatus = 'requesting';
      _screenError = null;
    });
    _stopScreenStream();

    try {
      final track = await lk.LocalVideoTrack.createScreenShareTrack(
        const lk.ScreenShareCaptureOptions(useiOSBroadcastExtension: true),
      );
      _lkScreenTrack = track;
      _screenStream = track.mediaStream;

      final videoTracks = _screenStream?.getVideoTracks() ?? [];
      if (videoTracks.isEmpty) {
        throw Exception('No display track selected.');
      }

      // Listen for user clicking "Stop sharing" in browser bar
      videoTracks.first.onEnded = () {
        if (mounted) {
          _stopScreenStream();
          setState(() {
            _screenStatus = 'pending';
          });
          _syncChecksToBackend();
        }
      };

      if (_screenRendererReady) {
        _screenRenderer.srcObject = _screenStream;
      }

      if (mounted) {
        setState(() {
          _screenStatus = 'shared';
        });
      }
      _syncChecksToBackend();
    } catch (e) {
      debugPrint('[Prestart] Screen share error or cancelled: $e');
      if (mounted) {
        setState(() {
          _screenStatus = 'denied';
          _screenError = 'Screen sharing cancelled or blocked by browser.';
        });
      }
      _syncChecksToBackend();
    }
  }

  void _stopScreenShareByUser() {
    _stopScreenStream();
    setState(() {
      _screenStatus = 'pending';
      _screenError = null;
    });
    _syncChecksToBackend();
  }

  Future<void> _runDeviceAndNetworkCheck() async {
    if (_deviceMode == 'DISABLED') {
      setState(() {
        _systemStatus = 'disabled_policy';
      });
      return;
    }
    setState(() {
      _systemStatus = 'checking';
    });

    final latency = await _apiService.measureNetworkLatencyMs();
    if (!mounted) return;
    setState(() {
      _latencyMs = latency;
      _systemStatus = latency >= 0 ? 'compatible' : 'warning';
    });
    _syncChecksToBackend();
  }

  Future<void> _runAllApplicableChecks() async {
    await _runDeviceAndNetworkCheck();
    if (_cameraMode != 'DISABLED') {
      await _requestCameraAccess(deviceId: _selectedVideoDeviceId);
    }
    if (_micMode != 'DISABLED') {
      await _requestMicAccess(deviceId: _selectedAudioDeviceId);
    }
  }

  Future<void> _syncChecksToBackend() async {
    final examId = widget.examId ?? '';
    if (examId.isEmpty) return;
    try {
      await _apiService.recordPrestartChecks(examId, {
        'camera_status': _cameraStatus.toUpperCase(),
        'microphone_status': _micStatus.toUpperCase(),
        'screen_share_status': _screenStatus.toUpperCase(),
        'system_status': _systemStatus.toUpperCase(),
        'readiness_status': _isAllMandatoryReady ? 'READY_TO_START' : 'CHECKING',
        'system_details': {
          'latency_ms': _latencyMs,
          'platform': kIsWeb ? 'Web Browser' : defaultTargetPlatform.name,
          'screen_width': MediaQuery.of(context).size.width.toInt(),
          'screen_height': MediaQuery.of(context).size.height.toInt(),
        },
      });
    } catch (_) {}
  }

  // --- READINESS LOGIC ---

  bool get _isCameraSatisfied =>
      _cameraMode == 'DISABLED' || _cameraMode == 'OPTIONAL' || _cameraStatus == 'allowed';

  bool get _isMicSatisfied =>
      _micMode == 'DISABLED' || _micMode == 'OPTIONAL' || _micStatus == 'allowed';

  bool get _isScreenSatisfied =>
      _screenMode == 'DISABLED' || _screenMode == 'OPTIONAL' || _screenStatus == 'shared';

  bool get _isDeviceSatisfied =>
      _deviceMode == 'DISABLED' || _deviceMode == 'OPTIONAL' || _systemStatus == 'compatible';

  bool get _isAllMandatoryReady =>
      _isCameraSatisfied && _isMicSatisfied && _isScreenSatisfied && _isDeviceSatisfied;

  bool get _canStartExam =>
      _isAllMandatoryReady && (!_acknowledgmentRequired || _isAcknowledged) && !_isCustomizeMode;

  List<String> get _missingMandatoryItems {
    final missing = <String>[];
    if (!_isCameraSatisfied) missing.add('Enable Camera');
    if (!_isMicSatisfied) missing.add('Enable Microphone');
    if (!_isScreenSatisfied) missing.add('Share Screen');
    if (!_isDeviceSatisfied) missing.add('Verify Internet Connection');
    return missing;
  }

  // --- SETTER CUSTOMIZATION ACTIONS ---

  Future<void> _savePolicyChanges() async {
    final examId = widget.examId ?? '';
    if (examId.isEmpty) return;

    setState(() => _isSavingConfig = true);
    try {
      await _apiService.updatePrestartConfig(examId, {
        'camera_mode': _cameraMode,
        'microphone_mode': _micMode,
        'screen_share_mode': _screenMode,
        'device_check_mode': _deviceMode,
        'fullscreen_required': _fullscreenRequired,
        'max_tab_switches': _maxTabSwitches,
        'acknowledgment_required': _acknowledgmentRequired,
        'warnings': _warnings,
      });
      _applyPolicyToStatuses();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Exam policy & warning rules saved for all candidates!'),
            backgroundColor: Color(0xFF059669),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save policy: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingConfig = false);
    }
  }

  Future<void> _saveCustomInstructions() async {
    final examId = widget.examId ?? '';
    if (examId.isEmpty) return;

    setState(() => _isSavingInstructions = true);
    try {
      await _apiService.savePrestartInstructions(examId, _instructions);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Exam instructions saved successfully!'),
            backgroundColor: Color(0xFF059669),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save instructions: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingInstructions = false);
    }
  }

  void _openInstructionDialog({int? editIndex}) {
    final isEdit = editIndex != null;
    final list = _instructions[_selectedTab] ?? [];
    final controller = TextEditingController(
      text: isEdit ? (list[editIndex]['description']?.toString() ?? '') : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Edit Instruction' : 'Add Instruction (${_tabLabel(_selectedTab)})'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter instruction text...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              setState(() {
                final updated = List<Map<String, dynamic>>.from(_instructions[_selectedTab] ?? []);
                if (isEdit) {
                  updated[editIndex] = {
                    ...updated[editIndex],
                    'description': text,
                  };
                } else {
                  updated.add({
                    'order': updated.length + 1,
                    'title': 'Rule ${updated.length + 1}',
                    'description': text,
                  });
                }
                _instructions[_selectedTab] = updated;
              });
              Navigator.of(ctx).pop();
            },
            child: Text(isEdit ? 'Update' : 'Add'),
          ),
        ],
      ),
    );
  }

  void _openWarningDialog({int? editIndex}) {
    final isEdit = editIndex != null;
    final controller = TextEditingController(
      text: isEdit ? _warnings[editIndex] : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEdit ? 'Edit Warning Rule' : 'Add Warning Rule'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter warning description...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              setState(() {
                if (isEdit) {
                  _warnings[editIndex] = text;
                } else {
                  _warnings.add(text);
                }
              });
              Navigator.of(ctx).pop();
            },
            child: Text(isEdit ? 'Update' : 'Add'),
          ),
        ],
      ),
    );
  }

  String _tabLabel(String key) {
    switch (key) {
      case 'general':
        return 'General';
      case 'during_exam':
        return 'During Exam';
      case 'proctoring':
        return 'Proctoring';
      case 'technical':
        return 'Technical';
      case 'submission':
        return 'Submission';
      default:
        return key;
    }
  }

  String _formatDuration(dynamic minutes) {
    if (minutes == null) return 'N/A';
    final m = int.tryParse(minutes.toString()) ?? 0;
    if (m <= 0) return 'N/A';
    if (m >= 60) {
      final h = m ~/ 60;
      final rem = m % 60;
      return rem == 0 ? '$h ${h == 1 ? 'Hour' : 'Hours'}' : '${h}h ${rem}m';
    }
    return '$m Mins';
  }

  void _onStartExamPressed() {
    if (!_canStartExam) return;
    final base = getExamsBaseRoute(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.play_circle_fill_rounded,
                color: Color(0xFF2563EB),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Ready to Begin Your Examination?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You are about to start "${_examData['title'] ?? 'Examination'}".',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  _dialogInfoRow('Subject:', _examData['subject']?.toString() ?? '-'),
                  const SizedBox(height: 6),
                  _dialogInfoRow('Duration:', _formatDuration(_examData['duration_minutes'])),
                  const SizedBox(height: 6),
                  _dialogInfoRow('Total Questions:', '${_examData['total_questions'] ?? 0}'),
                  const SizedBox(height: 6),
                  _dialogInfoRow('Total Marks:', '${_examData['total_marks'] ?? 100}'),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.35)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFFD97706)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Once you confirm, your server-authoritative countdown timer begins immediately and cannot be paused.',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Cancel / Review'),
          ),
          ElevatedButton.icon(
            icon: _isSubmittingAck
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.arrow_forward_rounded, size: 18),
            label: const Text(
              'Confirm & Start Examination',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1D4ED8),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            onPressed: _isSubmittingAck
                ? null
                : () async {
                    setState(() => _isSubmittingAck = true);
                    final examId = widget.examId ?? '';
                    try {
                      await _apiService.recordPrestartAcknowledgment(
                        examId,
                        acknowledged: true,
                      );
                    } catch (e) {
                      debugPrint('[Prestart] Acknowledgment record warning: $e');
                    } finally {
                      if (mounted) setState(() => _isSubmittingAck = false);
                    }
                    if (dialogCtx.mounted) {
                      Navigator.of(dialogCtx).pop();
                    }
                    if (_lkScreenTrack != null && _screenStatus == 'shared') {
                      ExamPrestartHandoff.handoffScreenTrack(_lkScreenTrack!);
                      _lkScreenTrack = null;
                      _screenStream = null;
                    } else if (_screenStream != null && _screenStatus == 'shared') {
                      ExamPrestartHandoff.handoffScreen(_screenStream!);
                      _screenStream = null;
                    }
                    _stopCameraStream();
                    _stopMicStream();
                    if (mounted) {
                      context.go('$base/take?examId=$examId');
                    }
                  },
          ),
        ],
      ),
    );
  }

  Widget _dialogInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = _ThemePalette(isDark);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: palette.scaffoldBg,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(palette.accentBlue)),
              const SizedBox(height: 16),
              Text(
                'Loading examination details & policies...',
                style: TextStyle(fontSize: 14, color: palette.secondaryText, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: palette.scaffoldBg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: LayoutBuilder(
                builder: (context, rootConstraints) {
                  final isMobileScreen = rootConstraints.maxWidth < 600;
                  return SingleChildScrollView(
                    padding: EdgeInsets.all(isMobileScreen ? 14.0 : 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    // 1. Top Header + Exam Setter Role Toggle
                    _buildHeader(palette),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 14),
                      _buildErrorBanner(_errorMessage!, palette),
                    ],
                    const SizedBox(height: 18),

                    // 2. Dynamic Exam Metadata Summary Bar
                    _buildExamSummaryBar(palette),
                    const SizedBox(height: 22),

                    // 3. Optional Exam Setter Customization Studio Panel (Visible ONLY in Setter Mode)
                    if (_canCustomize && _isCustomizeMode) ...[
                      _buildSetterPolicyConfiguratorCard(palette),
                      const SizedBox(height: 22),
                    ],

                    // 4. Main Responsive Two-Column Workspace
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isDesktop = constraints.maxWidth >= 1024;
                        if (isDesktop) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 66,
                                child: Column(
                                  children: [
                                    _buildSystemCheckCard(palette),
                                    const SizedBox(height: 20),
                                    _buildInstructionsCard(palette),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 34,
                                child: Column(
                                  children: [
                                    _buildExamReadinessCard(palette),
                                    const SizedBox(height: 20),
                                    _buildImportantWarningsCard(palette),
                                    const SizedBox(height: 20),
                                    _buildAcknowledgmentCard(palette),
                                  ],
                                ),
                              ),
                            ],
                          );
                        } else {
                          return Column(
                            children: [
                              _buildSystemCheckCard(palette),
                              const SizedBox(height: 20),
                              _buildInstructionsCard(palette),
                              const SizedBox(height: 20),
                              _buildExamReadinessCard(palette),
                              const SizedBox(height: 20),
                              _buildImportantWarningsCard(palette),
                              const SizedBox(height: 20),
                              _buildAcknowledgmentCard(palette),
                            ],
                          );
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),

            // 5. Sticky Bottom Bar
            _buildStickyBottomBar(palette),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBanner(String msg, _ThemePalette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: palette.redBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.redText.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: palette.redText, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg, style: TextStyle(fontSize: 12.5, color: palette.redText, fontWeight: FontWeight.w500)),
          ),
          TextButton(
            onPressed: _loadPrestartData,
            child: Text('Retry', style: TextStyle(color: palette.redText, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(_ThemePalette palette) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 760;

        final titleBlock = Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.assignment_outlined, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Examination – Pre-Start Instructions & System Check',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: palette.primaryText,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _isCustomizeMode
                        ? 'Exam Setter Mode: Configure dynamic device policies, instructions, and warnings for this examination.'
                        : 'Please review instructions carefully and grant required system permissions before starting.',
                    style: TextStyle(fontSize: 13, color: palette.secondaryText),
                  ),
                ],
              ),
            ),
          ],
        );

        final modeSwitcher = _canCustomize
            ? Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: palette.cardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: palette.borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _modeButton(
                      label: 'Candidate View',
                      icon: Icons.visibility_outlined,
                      active: !_isCustomizeMode,
                      palette: palette,
                      onTap: () => setState(() => _isCustomizeMode = false),
                    ),
                    const SizedBox(width: 4),
                    _modeButton(
                      label: 'Customize Exam Rules',
                      icon: Icons.tune_rounded,
                      active: _isCustomizeMode,
                      palette: palette,
                      onTap: () => setState(() => _isCustomizeMode = true),
                    ),
                  ],
                ),
              )
            : Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: palette.cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: palette.borderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 14, color: palette.secondaryText),
                    const SizedBox(width: 6),
                    Text(
                      'Read-Only Policy (${(_candidateData['name'] ?? 'Candidate')})',
                      style: TextStyle(fontSize: 11.5, color: palette.secondaryText, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleBlock,
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: modeSwitcher,
              ),
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: titleBlock),
            const SizedBox(width: 16),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: modeSwitcher,
            ),
          ],
        );
      },
    );
  }

  Widget _modeButton({
    required String label,
    required IconData icon,
    required bool active,
    required _ThemePalette palette,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: active ? Colors.white : palette.secondaryText),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : palette.secondaryText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- DYNAMIC EXAM SUMMARY BAR ---
  Widget _buildExamSummaryBar(_ThemePalette palette) {
    final title = _examData['title']?.toString() ?? 'Loading...';
    final subject = _examData['subject']?.toString() ?? 'General';
    final category = _examData['exam_category']?.toString() ?? '';
    final examMode = _examData['exam_mode']?.toString() ?? 'Online';
    final duration = _formatDuration(_examData['duration_minutes']);
    final totalMarks = '${_examData['total_marks'] ?? 100}';
    final totalQuestions = '${_examData['total_questions'] ?? 0}';
    final startTime = _examData['start_time']?.toString() ?? 'Flexible';
    final endTime = _examData['end_time']?.toString() ?? 'Auto-End';

    String targetScope = _examData['target_scope']?.toString() ?? 'All Candidates';
    final candClass = _candidateData['class_name']?.toString();
    final candSec = _candidateData['section_name']?.toString();
    if (candClass != null && candClass.isNotEmpty) {
      targetScope = (candSec != null && candSec.isNotEmpty) ? '$candClass – $candSec' : candClass;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.borderColor),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 1350;
          final examTitleWidget = Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.description_rounded, color: palette.accentBlue, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: palette.primaryText),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: subject,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: palette.accentBlue),
                          ),
                          if (category.isNotEmpty) ...[
                            TextSpan(text: '  •  ', style: TextStyle(color: palette.secondaryText, fontSize: 12)),
                            TextSpan(
                              text: '$category ($examMode)',
                              style: TextStyle(fontSize: 12, color: palette.secondaryText),
                            ),
                          ],
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          );

          final statWidgets = [
            _buildStatItem(Icons.group_outlined, 'Target / Class', targetScope, palette, maxValueWidth: isNarrow ? null : 160),
            _buildStatItem(Icons.quiz_outlined, 'Questions', totalQuestions, palette),
            _buildStatItem(Icons.military_tech_outlined, 'Total Marks', totalMarks, palette),
            _buildStatItem(Icons.schedule_outlined, 'Duration', duration, palette),
            _buildStatItem(Icons.event_outlined, 'Start Time', startTime, palette),
            _buildStatItem(Icons.event_busy_outlined, 'End Time', endTime, palette),
          ];

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                examTitleWidget,
                const SizedBox(height: 12),
                Divider(height: 1, color: palette.borderColor),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 20,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: statWidgets,
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(flex: 4, child: examTitleWidget),
              Container(
                height: 38,
                width: 1,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: palette.borderColor,
              ),
              Expanded(
                flex: 6,
                child: Wrap(
                  spacing: 16,
                  runSpacing: 10,
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: statWidgets,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatItem(
    IconData icon,
    String label,
    String value,
    _ThemePalette palette, {
    double? maxValueWidth,
  }) {
    return Tooltip(
      message: '$label: $value',
      waitDuration: const Duration(milliseconds: 300),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 17, color: palette.accentBlue),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: palette.secondaryText, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxValueWidth ?? 220),
                child: Text(
                  value,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: palette.primaryText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- SETTER CUSTOMIZATION STUDIO PANEL ---
  Widget _buildSetterPolicyConfiguratorCard(_ThemePalette palette) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.accentBlue.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, c) {
              final isNarrow = c.maxWidth < 640;
              final infoBlock = Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.admin_panel_settings_rounded, color: palette.accentBlue, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Exam Setter Customization Studio',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: palette.primaryText),
                        ),
                        Text(
                          'Set which hardware permissions are Mandatory, Optional, or Disabled for all target candidates taking this exam.',
                          style: TextStyle(fontSize: 12, color: palette.secondaryText),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final saveBtn = ElevatedButton.icon(
                icon: _isSavingConfig
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded, size: 16),
                label: const Text('Save Policy Changes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _isSavingConfig ? null : _savePolicyChanges,
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    infoBlock,
                    const SizedBox(height: 12),
                    saveBtn,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: infoBlock),
                  const SizedBox(width: 14),
                  saveBtn,
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          Divider(height: 1, color: palette.borderColor),
          const SizedBox(height: 18),

          // Tri-State Grid
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _buildTriStateSelector(
                label: 'Camera Proctoring',
                icon: Icons.videocam_outlined,
                value: _cameraMode,
                palette: palette,
                onChanged: (val) => setState(() {
                  _cameraMode = val;
                  _applyPolicyToStatuses();
                }),
              ),
              _buildTriStateSelector(
                label: 'Microphone Access',
                icon: Icons.mic_none_outlined,
                value: _micMode,
                palette: palette,
                onChanged: (val) => setState(() {
                  _micMode = val;
                  _applyPolicyToStatuses();
                }),
              ),
              _buildTriStateSelector(
                label: 'Screen Share',
                icon: Icons.screen_share_outlined,
                value: _screenMode,
                palette: palette,
                onChanged: (val) => setState(() {
                  _screenMode = val;
                  _applyPolicyToStatuses();
                }),
              ),
              _buildTriStateSelector(
                label: 'Device & Network Check',
                icon: Icons.wifi_tethering_rounded,
                value: _deviceMode,
                palette: palette,
                onChanged: (val) => setState(() {
                  _deviceMode = val;
                  _applyPolicyToStatuses();
                }),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Extra Policy Controls
          Wrap(
            spacing: 24,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: _fullscreenRequired,
                      activeThumbColor: const Color(0xFF2563EB),
                      onChanged: (v) => setState(() => _fullscreenRequired = v),
                    ),
                    const SizedBox(width: 6),
                    Text('Enforce Fullscreen Mode', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: palette.primaryText)),
                  ],
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: _acknowledgmentRequired,
                      activeThumbColor: const Color(0xFF2563EB),
                      onChanged: (v) => setState(() => _acknowledgmentRequired = v),
                    ),
                    const SizedBox(width: 6),
                    Text('Require Rule Acknowledgment', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: palette.primaryText)),
                  ],
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Max Tab Switches: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: palette.primaryText)),
                    const SizedBox(width: 8),
                    AppSearchableDropdown<int>.fromMenuItems(
                      value: [1, 2, 3, 5, 10, 99].contains(_maxTabSwitches) ? _maxTabSwitches : 3,
                      dropdownColor: palette.cardBg,
                      style: TextStyle(fontSize: 13, color: palette.primaryText, fontWeight: FontWeight.w600),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('1 Warning')),
                        DropdownMenuItem(value: 2, child: Text('2 Warnings')),
                        DropdownMenuItem(value: 3, child: Text('3 Warnings')),
                        DropdownMenuItem(value: 5, child: Text('5 Warnings')),
                        DropdownMenuItem(value: 10, child: Text('10 Warnings')),
                        DropdownMenuItem(value: 99, child: Text('Unlimited')),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _maxTabSwitches = v);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTriStateSelector({
    required String label,
    required IconData icon,
    required String value,
    required _ThemePalette palette,
    required ValueChanged<String> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.innerCardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: palette.accentBlue),
                const SizedBox(width: 6),
                Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: palette.primaryText)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _policyOptionBtn('REQUIRED', 'Mandatory', value, palette, onChanged),
                const SizedBox(width: 6),
                _policyOptionBtn('OPTIONAL', 'Optional', value, palette, onChanged),
                const SizedBox(width: 6),
                _policyOptionBtn('DISABLED', 'No Need', value, palette, onChanged),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _policyOptionBtn(
    String code,
    String label,
    String current,
    _ThemePalette palette,
    ValueChanged<String> onChanged,
  ) {
    final active = current == code;
    Color activeColor = const Color(0xFF2563EB);
    if (code == 'OPTIONAL') activeColor = const Color(0xFFD97706);
    if (code == 'DISABLED') activeColor = const Color(0xFF64748B);

    return InkWell(
      onTap: () => onChanged(code),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? activeColor : palette.cardBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: active ? activeColor : palette.borderColor),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: active ? Colors.white : palette.secondaryText,
          ),
        ),
      ),
    );
  }

  // --- SYSTEM & PERMISSIONS CHECK CARD ---
  Widget _buildSystemCheckCard(_ThemePalette palette) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, c) {
              final isNarrow = c.maxWidth < 480;
              final titleBlock = Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.shield_outlined, color: palette.accentBlue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'System & Permissions Check',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: palette.primaryText),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Enable required hardware permissions below. You can select devices and test live feeds before starting.',
                          style: TextStyle(fontSize: 12, color: palette.secondaryText),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              final runBtn = OutlinedButton.icon(
                icon: Icon(Icons.refresh_rounded, size: 16, color: palette.accentBlue),
                label: Text('Run Checks', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: palette.accentBlue)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  side: BorderSide(color: palette.accentBlue.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _runAllApplicableChecks,
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleBlock,
                    const SizedBox(height: 10),
                    runBtn,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: titleBlock),
                  const SizedBox(width: 12),
                  runBtn,
                ],
              );
            },
          ),
          const SizedBox(height: 18),

          // 4 Interactive Hardware Check Cards
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 560) {
                return Column(
                  children: [
                    _buildCameraCard(palette),
                    const SizedBox(height: 14),
                    _buildMicrophoneCard(palette),
                    const SizedBox(height: 14),
                    _buildScreenShareCard(palette),
                    const SizedBox(height: 14),
                    _buildDeviceNetworkCard(palette),
                  ],
                );
              } else if (constraints.maxWidth < 1040) {
                return Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildCameraCard(palette)),
                        const SizedBox(width: 14),
                        Expanded(child: _buildMicrophoneCard(palette)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildScreenShareCard(palette)),
                        const SizedBox(width: 14),
                        Expanded(child: _buildDeviceNetworkCard(palette)),
                      ],
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildCameraCard(palette)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildMicrophoneCard(palette)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildScreenShareCard(palette)),
                  const SizedBox(width: 12),
                  Expanded(child: _buildDeviceNetworkCard(palette)),
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Dynamic Status Banner
          _buildSystemSummaryBanner(palette),
        ],
      ),
    );
  }

  Widget _buildSystemSummaryBanner(_ThemePalette palette) {
    if (_isAllMandatoryReady) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: palette.greenBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.greenText.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_rounded, color: palette.greenText, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'All mandatory system checks are complete! Review the instructions and confirm below to begin.',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: palette.greenText),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: palette.amberBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: palette.amberText.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.pending_actions_rounded, color: palette.amberText, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Action Required: Please complete mandatory permissions (${_missingMandatoryItems.join(", ")}) to unlock Start Exam.',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: palette.amberText),
            ),
          ),
        ],
      ),
    );
  }

  // --- 1. INTERACTIVE CAMERA CARD ---
  Widget _buildCameraCard(_ThemePalette palette) {
    final statusBadge = _statusPillFor(_cameraStatus, _cameraMode, palette);
    final isDisabledPolicy = _cameraMode == 'DISABLED';

    return _innerTestCardShell(
      palette: palette,
      icon: isDisabledPolicy ? Icons.videocam_off_outlined : Icons.videocam_outlined,
      title: 'Camera',
      policyMode: _cameraMode,
      statusBadge: statusBadge,
      child: Column(
        children: [
          Container(
            height: 112,
            width: double.infinity,
            decoration: BoxDecoration(
              color: palette.previewBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _cameraStatus == 'allowed' ? palette.greenText.withValues(alpha: 0.6) : palette.borderColor,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: isDisabledPolicy
                ? _buildDisabledBox(Icons.videocam_off_outlined, 'Not Required by Policy', palette)
                : _cameraStatus == 'allowed' && _cameraStream != null && _cameraRendererReady
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          RTCVideoView(
                            _cameraRenderer,
                            mirror: true,
                            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                          ),
                          Positioned(
                            bottom: 6,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.fiber_manual_record, color: Color(0xFF22C55E), size: 8),
                                  SizedBox(width: 4),
                                  Text('Live Camera', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_cameraStatus == 'requesting')
                                SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: palette.accentBlue))
                              else
                                Icon(
                                  _cameraStatus == 'denied' ? Icons.no_photography_outlined : Icons.videocam_outlined,
                                  size: 28,
                                  color: _cameraStatus == 'denied' ? palette.redText : palette.secondaryText,
                                ),
                              const SizedBox(height: 6),
                              Text(
                                _cameraStatus == 'requesting'
                                    ? 'Requesting permission...'
                                    : (_cameraError ?? 'Camera is currently inactive'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: _cameraStatus == 'denied' ? palette.redText : palette.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
          ),
          const SizedBox(height: 8),
          if (!isDisabledPolicy) ...[
            if (_videoDevices.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: SizedBox(
                  height: 28,
                  child: AppSearchableDropdown<String>.fromMenuItems(
                    isExpanded: true,
                    isDense: true,
                    dropdownColor: palette.cardBg,
                    value: _videoDevices.any((d) => d.deviceId == _selectedVideoDeviceId)
                        ? _selectedVideoDeviceId
                        : _videoDevices.first.deviceId,
                    style: TextStyle(fontSize: 10.5, color: palette.primaryText),
                    items: _videoDevices.asMap().entries.map((e) {
                      final label = e.value.label.isNotEmpty ? e.value.label : 'Camera ${e.key + 1}';
                      return DropdownMenuItem(value: e.value.deviceId, child: Text(label, overflow: TextOverflow.ellipsis));
                    }).toList(),
                    onChanged: (devId) {
                      if (devId != null) _requestCameraAccess(deviceId: devId);
                    },
                  ),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: _cameraStatus == 'allowed'
                  ? OutlinedButton.icon(
                      icon: Icon(Icons.videocam_off_outlined, size: 14, color: palette.secondaryText),
                      label: Text('Stop Camera', style: TextStyle(fontSize: 11.5, color: palette.secondaryText)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        side: BorderSide(color: palette.borderColor),
                      ),
                      onPressed: _disableCameraByUser,
                    )
                  : ElevatedButton.icon(
                      icon: const Icon(Icons.videocam_rounded, size: 14),
                      label: Text(_cameraStatus == 'denied' ? 'Retry Camera' : 'Enable Camera', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: _cameraStatus == 'requesting' ? null : () => _requestCameraAccess(deviceId: _selectedVideoDeviceId),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  // --- 2. INTERACTIVE MICROPHONE CARD ---
  Widget _buildMicrophoneCard(_ThemePalette palette) {
    final statusBadge = _statusPillFor(_micStatus, _micMode, palette);
    final isDisabledPolicy = _micMode == 'DISABLED';

    return _innerTestCardShell(
      palette: palette,
      icon: isDisabledPolicy ? Icons.mic_off_outlined : Icons.mic_none_outlined,
      title: 'Microphone',
      policyMode: _micMode,
      statusBadge: statusBadge,
      child: Column(
        children: [
          Container(
            height: 112,
            width: double.infinity,
            decoration: BoxDecoration(
              color: palette.previewBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _micStatus == 'allowed' ? palette.greenText.withValues(alpha: 0.6) : palette.borderColor,
              ),
            ),
            child: isDisabledPolicy
                ? _buildDisabledBox(Icons.mic_off_outlined, 'Not Required by Policy', palette)
                : _micStatus == 'allowed'
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            height: 46,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: _waveformHeights.map((h) {
                                return Container(
                                  width: 3.5,
                                  height: h,
                                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                                  decoration: BoxDecoration(
                                    color: palette.accentBlue,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Audio Stream Active',
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: palette.greenText),
                          ),
                        ],
                      )
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_micStatus == 'requesting')
                                SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: palette.accentBlue))
                              else
                                Icon(
                                  _micStatus == 'denied' ? Icons.mic_off_rounded : Icons.mic_none_rounded,
                                  size: 28,
                                  color: _micStatus == 'denied' ? palette.redText : palette.secondaryText,
                                ),
                              const SizedBox(height: 6),
                              Text(
                                _micStatus == 'requesting'
                                    ? 'Requesting microphone...'
                                    : (_micError ?? 'Microphone is inactive'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: _micStatus == 'denied' ? palette.redText : palette.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
          ),
          const SizedBox(height: 8),
          if (!isDisabledPolicy) ...[
            if (_audioDevices.length > 1)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: SizedBox(
                  height: 28,
                  child: AppSearchableDropdown<String>.fromMenuItems(
                    isExpanded: true,
                    isDense: true,
                    dropdownColor: palette.cardBg,
                    value: _audioDevices.any((d) => d.deviceId == _selectedAudioDeviceId)
                        ? _selectedAudioDeviceId
                        : _audioDevices.first.deviceId,
                    style: TextStyle(fontSize: 10.5, color: palette.primaryText),
                    items: _audioDevices.asMap().entries.map((e) {
                      final label = e.value.label.isNotEmpty ? e.value.label : 'Mic ${e.key + 1}';
                      return DropdownMenuItem(value: e.value.deviceId, child: Text(label, overflow: TextOverflow.ellipsis));
                    }).toList(),
                    onChanged: (devId) {
                      if (devId != null) _requestMicAccess(deviceId: devId);
                    },
                  ),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: _micStatus == 'allowed'
                  ? OutlinedButton.icon(
                      icon: Icon(Icons.mic_off_outlined, size: 14, color: palette.secondaryText),
                      label: Text('Stop Mic', style: TextStyle(fontSize: 11.5, color: palette.secondaryText)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        side: BorderSide(color: palette.borderColor),
                      ),
                      onPressed: _disableMicByUser,
                    )
                  : ElevatedButton.icon(
                      icon: const Icon(Icons.mic_rounded, size: 14),
                      label: Text(_micStatus == 'denied' ? 'Retry Microphone' : 'Enable Microphone', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: _micStatus == 'requesting' ? null : () => _requestMicAccess(deviceId: _selectedAudioDeviceId),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  // --- 3. INTERACTIVE SCREEN SHARE CARD ---
  Widget _buildScreenShareCard(_ThemePalette palette) {
    final statusBadge = _statusPillFor(_screenStatus, _screenMode, palette);
    final isDisabledPolicy = _screenMode == 'DISABLED';

    return _innerTestCardShell(
      palette: palette,
      icon: isDisabledPolicy ? Icons.stop_screen_share_outlined : Icons.screen_share_outlined,
      title: 'Screen Share',
      policyMode: _screenMode,
      statusBadge: statusBadge,
      child: Column(
        children: [
          Container(
            height: 112,
            width: double.infinity,
            decoration: BoxDecoration(
              color: palette.previewBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _screenStatus == 'shared' ? palette.greenText.withValues(alpha: 0.7) : palette.borderColor,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: isDisabledPolicy
                ? _buildDisabledBox(Icons.stop_screen_share_outlined, 'Not Required by Policy', palette)
                : _screenStatus == 'shared' && _screenStream != null && _screenRendererReady
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          RTCVideoView(
                            _screenRenderer,
                            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                          ),
                          Positioned(
                            bottom: 6,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.72),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.cast_connected_rounded, color: Color(0xFF22C55E), size: 10),
                                  SizedBox(width: 4),
                                  Text('Screen Live', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : Center(
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_screenStatus == 'requesting')
                                SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: palette.accentBlue))
                              else
                                Icon(
                                  Icons.present_to_all_rounded,
                                  size: 28,
                                  color: _screenStatus == 'denied' ? palette.redText : palette.secondaryText,
                                ),
                              const SizedBox(height: 6),
                              Text(
                                _screenStatus == 'requesting'
                                    ? 'Select a screen in browser popup...'
                                    : (_screenError ?? 'Click "Share Screen" to grant screen capture'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: _screenStatus == 'denied' ? palette.redText : palette.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
          ),
          const SizedBox(height: 8),
          if (!isDisabledPolicy)
            SizedBox(
              width: double.infinity,
              child: _screenStatus == 'shared'
                  ? OutlinedButton.icon(
                      icon: Icon(Icons.stop_screen_share_outlined, size: 14, color: palette.secondaryText),
                      label: Text('Stop Sharing', style: TextStyle(fontSize: 11.5, color: palette.secondaryText)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        side: BorderSide(color: palette.borderColor),
                      ),
                      onPressed: _stopScreenShareByUser,
                    )
                  : ElevatedButton.icon(
                      icon: const Icon(Icons.screen_share_rounded, size: 14),
                      label: Text(_screenStatus == 'denied' ? 'Retry Share Screen' : 'Share Screen', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onPressed: _screenStatus == 'requesting' ? null : _requestScreenShare,
                    ),
            ),
        ],
      ),
    );
  }

  // --- 4. INTERACTIVE DEVICE & NETWORK CARD ---
  Widget _buildDeviceNetworkCard(_ThemePalette palette) {
    final statusBadge = _statusPillFor(_systemStatus, _deviceMode, palette);
    final isDisabledPolicy = _deviceMode == 'DISABLED';
    const platformText = kIsWeb ? 'Modern Browser (Active)' : 'Desktop / Native App';
    final netText = _systemStatus == 'checking'
        ? 'Measuring RTT...'
        : (_latencyMs >= 0 ? 'Online (${_latencyMs}ms ping)' : 'Connection unstable');
    final size = MediaQuery.of(context).size;
    final resText = 'Display ${size.width.toInt()}×${size.height.toInt()}';

    return _innerTestCardShell(
      palette: palette,
      icon: Icons.laptop_chromebook_outlined,
      title: 'Device & Net',
      policyMode: _deviceMode,
      statusBadge: statusBadge,
      child: Column(
        children: [
          Container(
            height: 112,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: palette.previewBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: palette.borderColor),
            ),
            child: isDisabledPolicy
                ? _buildDisabledBox(Icons.phonelink_off_rounded, 'Not Required by Policy', palette)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _deviceRow(Icons.check_circle_rounded, platformText, palette.greenText, palette),
                      _deviceRow(
                        _latencyMs >= 0 ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                        netText,
                        _latencyMs >= 0 ? palette.greenText : palette.amberText,
                        palette,
                      ),
                      _deviceRow(Icons.check_circle_rounded, resText, palette.greenText, palette),
                    ],
                  ),
          ),
          const SizedBox(height: 8),
          if (!isDisabledPolicy)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: Icon(Icons.network_check_rounded, size: 14, color: palette.accentBlue),
                label: Text('Re-test Network', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: palette.accentBlue)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  side: BorderSide(color: palette.accentBlue.withValues(alpha: 0.4)),
                ),
                onPressed: _runDeviceAndNetworkCheck,
              ),
            ),
        ],
      ),
    );
  }

  Widget _deviceRow(IconData icon, String text, Color iconColor, _ThemePalette palette) {
    return Row(
      children: [
        Icon(icon, color: iconColor, size: 14),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: palette.primaryText),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildDisabledBox(IconData icon, String text, _ThemePalette palette) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 26, color: palette.secondaryText),
          const SizedBox(height: 6),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: palette.secondaryText, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _innerTestCardShell({
    required _ThemePalette palette,
    required IconData icon,
    required String title,
    required String policyMode,
    required Widget statusBadge,
    required Widget child,
  }) {
    final policyLabel = policyMode == 'REQUIRED'
        ? 'Mandatory'
        : (policyMode == 'OPTIONAL' ? 'Optional' : 'Disabled');
    final policyColor = policyMode == 'REQUIRED'
        ? palette.accentBlue
        : (policyMode == 'OPTIONAL' ? palette.amberText : palette.secondaryText);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.innerCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: palette.accentBlue, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: palette.primaryText),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      policyLabel,
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: policyColor),
                    ),
                  ],
                ),
              ),
              statusBadge,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _statusPillFor(String status, String policyMode, _ThemePalette palette) {
    if (policyMode == 'DISABLED' || status == 'disabled_policy') {
      return _pill('Off', Icons.block_rounded, palette.greyText, palette.greyBg);
    }
    switch (status) {
      case 'allowed':
        return _pill('Allowed', Icons.check_circle_rounded, palette.greenText, palette.greenBg);
      case 'shared':
        return _pill('Shared', Icons.check_circle_rounded, palette.greenText, palette.greenBg);
      case 'compatible':
        return _pill('Ready', Icons.check_circle_rounded, palette.greenText, palette.greenBg);
      case 'requesting':
      case 'checking':
        return _pill('Testing', Icons.hourglass_top_rounded, palette.amberText, palette.amberBg);
      case 'denied':
      case 'warning':
        return _pill('Denied', Icons.error_outline_rounded, palette.redText, palette.redBg);
      default:
        return _pill(
          policyMode == 'OPTIONAL' ? 'Optional' : 'Pending',
          Icons.radio_button_unchecked_rounded,
          palette.amberText,
          palette.amberBg,
        );
    }
  }

  Widget _pill(String label, IconData icon, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor, size: 11),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: textColor)),
        ],
      ),
    );
  }

  // --- IMPORTANT INSTRUCTIONS CARD ---
  Widget _buildInstructionsCard(_ThemePalette palette) {
    final activeList = _instructions[_selectedTab] ?? [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, c) {
              final isNarrow = c.maxWidth < 560;
              final titleBlock = Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.info_outline_rounded, color: palette.accentBlue, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Important Instructions',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: palette.primaryText),
                    ),
                  ),
                ],
              );

              final actionBtns = (_canCustomize && _isCustomizeMode)
                  ? Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Add Rule', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: palette.accentBlue,
                            side: BorderSide(color: palette.accentBlue.withValues(alpha: 0.5)),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onPressed: () => _openInstructionDialog(),
                        ),
                        ElevatedButton.icon(
                          icon: _isSavingInstructions
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.save_rounded, size: 15),
                          label: const Text('Save Instructions', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF059669),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          onPressed: _isSavingInstructions ? null : _saveCustomInstructions,
                        ),
                      ],
                    )
                  : null;

              if (actionBtns == null) return titleBlock;

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleBlock,
                    const SizedBox(height: 10),
                    actionBtns,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: titleBlock),
                  const SizedBox(width: 12),
                  actionBtns,
                ],
              );
            },
          ),
          const SizedBox(height: 16),

          // Category Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildInstructionTab('general', 'General', Icons.assignment_outlined, palette),
                const SizedBox(width: 8),
                _buildInstructionTab('during_exam', 'During Exam', Icons.access_time_rounded, palette),
                const SizedBox(width: 8),
                _buildInstructionTab('proctoring', 'Proctoring', Icons.videocam_outlined, palette),
                const SizedBox(width: 8),
                _buildInstructionTab('technical', 'Technical', Icons.computer_outlined, palette),
                const SizedBox(width: 8),
                _buildInstructionTab('submission', 'Submission', Icons.send_outlined, palette),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (activeList.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No instructions listed for this category.',
                  style: TextStyle(color: palette.secondaryText, fontSize: 13),
                ),
              ),
            )
          else
            Column(
              children: activeList.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                final text = item['description']?.toString() ?? item['title']?.toString() ?? '';
                final isLast = idx == activeList.length - 1;

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 26,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${idx + 1}',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: palette.accentBlue),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              text,
                              style: TextStyle(fontSize: 13.5, color: palette.primaryText, height: 1.45),
                            ),
                          ),
                          if (_canCustomize && _isCustomizeMode) ...[
                            IconButton(
                              icon: Icon(Icons.edit_outlined, size: 16, color: palette.accentBlue),
                              tooltip: 'Edit rule',
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              onPressed: () => _openInstructionDialog(editIndex: idx),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline_rounded, size: 16, color: palette.redText),
                              tooltip: 'Delete rule',
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              onPressed: () {
                                setState(() {
                                  final list = List<Map<String, dynamic>>.from(_instructions[_selectedTab] ?? []);
                                  list.removeAt(idx);
                                  _instructions[_selectedTab] = list;
                                });
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!isLast) Divider(height: 1, color: palette.dividerColor),
                  ],
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildInstructionTab(String key, String label, IconData icon, _ThemePalette palette) {
    final isSelected = _selectedTab == key;
    return InkWell(
      onTap: () => setState(() => _selectedTab = key),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : palette.tabUnselectedBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: isSelected ? Colors.white : palette.tabUnselectedText),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : palette.tabUnselectedText,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- RIGHT COLUMN: DYNAMIC EXAM READINESS CARD ---
  Widget _buildExamReadinessCard(_ThemePalette palette) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.verified_outlined, color: palette.accentBlue, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Exam Readiness',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: palette.primaryText),
                ),
              ),
              _isAllMandatoryReady
                  ? _pill('READY TO START', Icons.check_circle_rounded, palette.greenText, palette.greenBg)
                  : _pill('ACTION NEEDED', Icons.pending_rounded, palette.amberText, palette.amberBg),
            ],
          ),
          const SizedBox(height: 18),

          _readinessChecklistRow(
            palette: palette,
            isDone: _isCameraSatisfied,
            isDisabled: _cameraMode == 'DISABLED',
            label: _cameraMode == 'DISABLED'
                ? 'Camera not required for this exam'
                : (_cameraStatus == 'allowed'
                    ? 'Camera permission granted & active'
                    : (_cameraMode == 'OPTIONAL' ? 'Camera optional (Currently off)' : 'Camera permission required')),
          ),
          const SizedBox(height: 12),
          _readinessChecklistRow(
            palette: palette,
            isDone: _isMicSatisfied,
            isDisabled: _micMode == 'DISABLED',
            label: _micMode == 'DISABLED'
                ? 'Microphone not required for this exam'
                : (_micStatus == 'allowed'
                    ? 'Microphone permission granted & active'
                    : (_micMode == 'OPTIONAL' ? 'Microphone optional (Currently off)' : 'Microphone permission required')),
          ),
          const SizedBox(height: 12),
          _readinessChecklistRow(
            palette: palette,
            isDone: _isScreenSatisfied,
            isDisabled: _screenMode == 'DISABLED',
            label: _screenMode == 'DISABLED'
                ? 'Screen sharing disabled by setter'
                : (_screenStatus == 'shared'
                    ? 'Screen sharing active'
                    : (_screenMode == 'OPTIONAL' ? 'Screen sharing optional (Not shared)' : 'Screen share required')),
          ),
          const SizedBox(height: 12),
          _readinessChecklistRow(
            palette: palette,
            isDone: _isDeviceSatisfied,
            isDisabled: _deviceMode == 'DISABLED',
            label: _latencyMs >= 0
                ? 'Network verified (${_latencyMs}ms latency)'
                : 'Checking network connection...',
          ),
          const SizedBox(height: 12),
          _readinessChecklistRow(
            palette: palette,
            isDone: true,
            isDisabled: false,
            label: _fullscreenRequired
                ? 'Fullscreen proctoring enforced (Max $_maxTabSwitches switches)'
                : 'Standard window mode permitted',
          ),
        ],
      ),
    );
  }

  Widget _readinessChecklistRow({
    required _ThemePalette palette,
    required bool isDone,
    required bool isDisabled,
    required String label,
  }) {
    final IconData icon;
    final Color color;
    if (isDisabled) {
      icon = Icons.remove_circle_outline_rounded;
      color = palette.secondaryText;
    } else if (isDone) {
      icon = Icons.check_circle_rounded;
      color = palette.greenText;
    } else {
      icon = Icons.radio_button_unchecked_rounded;
      color = palette.amberText;
    }

    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDisabled ? palette.secondaryText : palette.primaryText,
            ),
          ),
        ),
      ],
    );
  }

  // --- RIGHT COLUMN: IMPORTANT WARNINGS CARD ---
  Widget _buildImportantWarningsCard(_ThemePalette palette) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: palette.warningBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.warningBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: palette.warningTitle, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Important Warnings',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: palette.warningTitle),
                ),
              ),
              if (_canCustomize && _isCustomizeMode)
                IconButton(
                  icon: Icon(Icons.add_circle_outline_rounded, size: 18, color: palette.warningTitle),
                  tooltip: 'Add warning rule',
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  onPressed: () => _openWarningDialog(),
                ),
            ],
          ),
          const SizedBox(height: 14),
          ..._warnings.asMap().entries.map((entry) {
            final idx = entry.key;
            final w = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(color: palette.warningTitle, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      w,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: palette.warningText,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (_canCustomize && _isCustomizeMode) ...[
                    IconButton(
                      icon: Icon(Icons.edit_outlined, size: 14, color: palette.warningTitle),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      onPressed: () => _openWarningDialog(editIndex: idx),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline_rounded, size: 14, color: palette.redText),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      onPressed: () {
                        setState(() => _warnings.removeAt(idx));
                      },
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // --- RIGHT COLUMN: ACKNOWLEDGMENT CHECKBOX ---
  Widget _buildAcknowledgmentCard(_ThemePalette palette) {
    if (!_acknowledgmentRequired) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: palette.cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: palette.borderColor),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 18, color: palette.greenText),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Rule acknowledgment check is waived for this examination.',
                style: TextStyle(fontSize: 12.5, color: palette.secondaryText),
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: () => setState(() => _isAcknowledged = !_isAcknowledged),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.cardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _isAcknowledged ? palette.accentBlue : palette.borderColor),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: Checkbox(
                value: _isAcknowledged,
                activeColor: const Color(0xFF2563EB),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                onChanged: (val) => setState(() => _isAcknowledged = val ?? false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'I have read and understood all the instructions, rules and warnings, and I am ready to take the exam.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: _isAcknowledged ? FontWeight.w600 : FontWeight.w500,
                  color: palette.primaryText,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- STICKY BOTTOM ACTION BAR ---
  Widget _buildStickyBottomBar(_ThemePalette palette) {
    String? disabledHint;
    if (_isCustomizeMode) {
      disabledHint = 'Switch back to "Candidate View" to start or preview taking the exam';
    } else if (!_isAllMandatoryReady) {
      disabledHint = 'Mandatory checks pending: ${_missingMandatoryItems.join(", ")}';
    } else if (_acknowledgmentRequired && !_isAcknowledged) {
      disabledHint = 'Check the acknowledgment box above to enable Start Exam';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: palette.cardBg,
        border: Border(top: BorderSide(color: palette.borderColor)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 680;

          if (isNarrow) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (disabledHint != null) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 14, color: palette.amberText),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          disabledHint,
                          style: TextStyle(fontSize: 11.5, color: palette.amberText, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: Icon(Icons.arrow_back_ios_new_rounded, size: 13, color: palette.primaryText),
                        label: Text(
                          'Back',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: palette.primaryText),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: palette.borderColor),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () {
                          final base = getExamsBaseRoute(context);
                          context.go(base);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow_rounded, size: 18, color: Colors.white),
                        label: const Text(
                          'Start Exam',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _canStartExam ? const Color(0xFF1D4ED8) : palette.greyBg,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: _canStartExam ? 2 : 0,
                        ),
                        onPressed: _canStartExam ? _onStartExamPressed : null,
                      ),
                    ),
                  ],
                ),
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                icon: Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: palette.primaryText),
                label: Text(
                  'Back to Examinations',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: palette.primaryText),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  side: BorderSide(color: palette.borderColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () {
                  final base = getExamsBaseRoute(context);
                  context.go(base);
                },
              ),
              const SizedBox(width: 16),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (disabledHint != null) ...[
                      Flexible(
                        child: Text(
                          disabledHint,
                          style: TextStyle(fontSize: 12, color: palette.amberText, fontWeight: FontWeight.w500),
                          textAlign: TextAlign.end,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 14),
                    ],
                    ElevatedButton.icon(
                      icon: const Icon(Icons.play_arrow_rounded, size: 20, color: Colors.white),
                      label: const Text(
                        'Start Exam',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _canStartExam ? const Color(0xFF1D4ED8) : palette.greyBg,
                        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: _canStartExam ? 2 : 0,
                      ),
                      onPressed: _canStartExam ? _onStartExamPressed : null,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ThemePalette {
  final bool isDark;
  _ThemePalette(this.isDark);

  Color get scaffoldBg => isDark ? const Color(0xFF0A1022) : const Color(0xFFF8FAFC);
  Color get cardBg => isDark ? const Color(0xFF131D38) : Colors.white;
  Color get innerCardBg => isDark ? const Color(0xFF0E172E) : const Color(0xFFF8FAFC);
  Color get previewBg => isDark ? const Color(0xFF090E1D) : const Color(0xFFF1F5F9);
  Color get borderColor => isDark ? const Color(0xFF233258) : const Color(0xFFE2E8F0);
  Color get dividerColor => isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
  Color get primaryText => isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
  Color get secondaryText => isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get accentBlue => isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);
  Color get tabUnselectedBg => isDark ? const Color(0xFF1A2747) : const Color(0xFFF1F5F9);
  Color get tabUnselectedText => isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);

  Color get warningBg => isDark ? const Color(0xFF241B0A) : const Color(0xFFFFFBEB);
  Color get warningBorder => isDark ? const Color(0xFF78350F) : const Color(0xFFFDE68A);
  Color get warningTitle => isDark ? const Color(0xFFFBBF24) : const Color(0xFF92400E);
  Color get warningText => isDark ? const Color(0xFFFDE68A) : const Color(0xFF78350F);

  Color get greenText => isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A);
  Color get greenBg => isDark ? const Color(0xFF064E3B).withValues(alpha: 0.45) : const Color(0xFFDCFCE7);

  Color get amberText => isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706);
  Color get amberBg => isDark ? const Color(0xFF78350F).withValues(alpha: 0.4) : const Color(0xFFFEF3C7);

  Color get redText => isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626);
  Color get redBg => isDark ? const Color(0xFF7F1D1D).withValues(alpha: 0.45) : const Color(0xFFFEE2E2);

  Color get greyText => isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get greyBg => isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
}
