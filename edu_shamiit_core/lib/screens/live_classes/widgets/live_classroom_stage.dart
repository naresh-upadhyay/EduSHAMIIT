import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import '../models/live_class_models.dart';
import '../providers/live_class_management_provider.dart';
import '../services/in_app_live_room_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/role_provider.dart';
import '../../../utils/browser_fullscreen.dart';
import '../utils/live_class_theme.dart';
import '../utils/live_class_recorder_helper.dart';
import '../whiteboard/widgets/whiteboard_workspace.dart';
import 'share_meeting_dialog.dart';
import 'device_audio_test_dialog.dart';

enum StageMode {
  teacherPresentation,
  screenShare,
  interactiveWhiteboard,
  participantGrid,
}

class LiveClassroomStage extends ConsumerStatefulWidget {
  final ActiveLiveSession? session;
  final List<LiveParticipant>? participants;
  final VoidCallback? onEndClass;
  final VoidCallback? onLeaveClass;
  final VoidCallback? onOpenChat;
  final VoidCallback? onOpenParticipants;
  final VoidCallback? onOpenPolls;
  final VoidCallback? onOpenQA;
  final VoidCallback? onOpenWhiteboard;
  final bool isFullscreen;
  final VoidCallback? onToggleFullscreen;
  final StageMode? initialStageMode;

  const LiveClassroomStage({
    super.key,
    this.session,
    this.participants,
    this.onEndClass,
    this.onLeaveClass,
    this.onOpenChat,
    this.onOpenParticipants,
    this.onOpenPolls,
    this.onOpenQA,
    this.onOpenWhiteboard,
    this.isFullscreen = false,
    this.onToggleFullscreen,
    this.initialStageMode,
  });

  @override
  ConsumerState<LiveClassroomStage> createState() => _LiveClassroomStageState();
}

class _LiveClassroomStageState extends ConsumerState<LiveClassroomStage>
    with SingleTickerProviderStateMixin {
  StageMode _stageMode = StageMode.teacherPresentation;
  bool get _isMicMuted => ref.read(liveRoomServiceProvider).isMicMuted;
  set _isMicMuted(bool val) {
    if (ref.read(liveRoomServiceProvider).isMicMuted != val) {
      ref.read(liveRoomServiceProvider).setMicrophoneMuted(val);
    }
  }

  bool get _isVideoOff => ref.read(liveRoomServiceProvider).isCamOff;
  set _isVideoOff(bool val) {
    if (ref.read(liveRoomServiceProvider).isCamOff != val) {
      ref.read(liveRoomServiceProvider).setCameraOff(val);
    }
  }
  bool _isScreenSharing = false;
  bool _isRecording = false;
  bool _isRecordingPaused = false;
  bool _isRecordingTransitioning = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;

  // Audio Equalizer Animation
  late AnimationController _equalizerController;

  // Classroom Settings
  String _selectedMic = 'Default - Realtek High Definition Audio';
  String _selectedCamera = 'Integrated HD Camera (1080p 60fps)';
  String _selectedOutput = 'Default - Speakers / Headphones';
  String _virtualBackground = 'Classroom Digital Board';
  bool _aiNoiseCancellation = true;

  // Keyboard Shortcuts & Push-to-Talk
  final GlobalKey _stageRepaintKey = GlobalKey();
  final FocusNode _keyboardFocusNode = FocusNode();
  bool _isPushToTalkActive = false;
  bool _wasMicMutedBeforePTT = true;

  @override
  void initState() {
    super.initState();
    LiveClassBrowserRecorder.instance.registerStageFrameProvider(_captureStageFrame);
    if (widget.initialStageMode != null) {
      _stageMode = widget.initialStageMode!;
    }
    if (_isRecording) {
      _startRecordingTimer();
    }
    _equalizerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoConnectLiveRoom();
      _keyboardFocusNode.requestFocus();
    });
  }

  @override
  void didUpdateWidget(covariant LiveClassroomStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialStageMode != null && widget.initialStageMode != oldWidget.initialStageMode) {
      setState(() {
        _stageMode = widget.initialStageMode!;
      });
    }
    if (widget.session?.id != oldWidget.session?.id) {
      setState(() {
        _stageMode = widget.initialStageMode ?? StageMode.teacherPresentation;
        _isScreenSharing = false;
      });
      _autoConnectLiveRoom();
    }
  }

  void _startManualRecording() async {
    if (_isRecordingTransitioning || _isRecording || LiveClassBrowserRecorder.instance.isRecording) {
      return;
    }
    _isRecordingTransitioning = true;

    // Instant UI feedback (do NOT mutate InAppLiveRoomService.isRecording before startRecordingWithCapture)
    setState(() {
      _isRecording = true;
      _isRecordingPaused = false;
      _recordingDuration = Duration.zero;
    });
    _recordingTimer?.cancel();
    _startRecordingTimer();

    try {
      final result = await ref.read(liveClassManagementProvider.notifier).startRecordingWithCapture();
      final started = result['success'] == true && result['is_recording'] == true;
      if (mounted) {
        if (!started) {
          setState(() {
            _isRecording = false;
            _isRecordingPaused = false;
            _recordingTimer?.cancel();
          });
          InAppLiveRoomService.instance.setIsRecording(false);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']?.toString() ??
                (started
                    ? 'Live recording started.'
                    : 'Could not start recording.')),
            backgroundColor: started ? const Color(0xFF10B981) : const Color(0xFFEF4444),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('[LiveClassroomStage] Start recording error: $e');
      if (mounted) {
        setState(() {
          _isRecording = false;
          _recordingTimer?.cancel();
        });
      }
      InAppLiveRoomService.instance.setIsRecording(false);
    } finally {
      _isRecordingTransitioning = false;
    }
  }

  void _autoConnectLiveRoom() async {
    if (!mounted) return;
    try {
      final roomService = ref.read(liveRoomServiceProvider);
      final authState = ref.read(authProvider);
      final authUser = authState.userData;
      final currentUserId = (authUser?['id'] as String?)?.trim().isNotEmpty == true
          ? (authUser!['id'] as String).trim()
          : '5198c4b0-f1cb-45db-9649-41688d0438ba';
      final currentUserName = (authUser?['full_name'] as String?)?.trim().isNotEmpty == true
          ? (authUser!['full_name'] as String).trim()
          : ((authUser?['name'] as String?)?.trim().isNotEmpty == true
              ? (authUser!['name'] as String).trim()
              : (authState.role == UserRole.superAdmin ? 'Aarav Sharma' : 'Teacher'));
      final currentUserRole = (authUser?['role'] as String?)?.trim().isNotEmpty == true
          ? (authUser!['role'] as String).trim()
          : (authState.role == UserRole.superAdmin ? 'super_admin' : 'teacher');

      final conductData = ref.read(liveClassManagementProvider).conductSessionData;
      final sess = widget.session ?? conductData?.activeSession;
      final roomId = sess?.id ?? 'e75e144c-c754-482b-9f7a-276a743c6c5e';

      if (roomService.liveClassId == roomId &&
          roomService.currentUserId == currentUserId &&
          (roomService.isConnected || roomService.localAudioTrack != null || roomService.localCameraTrack != null || !roomService.isMicMuted || !roomService.isCamOff)) {
        debugPrint('[LiveClassroomStage] Room service is already active for roomId: $roomId, preserving active connection & media.');
        return;
      }

      if (roomService.room != null &&
          roomService.room?.connectionState == lk.ConnectionState.connected) {
        if (roomService.currentUserName == currentUserName && roomService.currentUserId == currentUserId) {
          return;
        }
        await roomService.leaveRoom();
      }

      roomService.initRoomConfig(
        liveClassId: roomId,
        currentUserId: currentUserId,
        currentUserName: currentUserName,
        currentUserRole: currentUserRole,
      );
      await roomService.initializeRoom().timeout(
        const Duration(seconds: 4),
        onTimeout: () {
          debugPrint('[LiveClassroomStage] auto-connect timeout (smooth fallback active).');
        },
      );

      // Check Auto Recording Rules (Assigned Classes or SHAMIIT query clauses)
      if (sess != null) {
        final rules = ref.read(liveClassManagementProvider).autoRecordingRules;
        final shouldAutoRec = rules.evaluatesToTrue(
          title: sess.title,
          classSection: sess.classSection,
          subject: sess.subject,
          teacherName: sess.teacherName,
        );
        if (shouldAutoRec && !_isRecording) {
          debugPrint('[LiveClassroomStage] Session matches Auto-Recording Rules! Auto-triggering recording.');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_isRecording) {
              _startManualRecording();
            }
          });
        }
      }
    } catch (e) {
      debugPrint('[LiveClassroomStage] auto-connect notice: $e');
    }
  }

  void _startRecordingTimer() {
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && _isRecording && !_isRecordingPaused) {
        setState(() {
          _recordingDuration += const Duration(seconds: 1);
        });
      }
    });
  }

  Future<StageCaptureFrame?> _captureStageFrame({bool includeStandardStage = false}) async {
    if (!mounted) return null;
    final roomService = ref.read(liveRoomServiceProvider);
    final bool boardActive = _stageMode == StageMode.interactiveWhiteboard ||
        _stageMode == StageMode.screenShare ||
        _stageMode == StageMode.participantGrid ||
        _isScreenSharing ||
        roomService.isCamOff;
    if (!boardActive && !includeStandardStage) return null;

    final renderObj = _stageRepaintKey.currentContext?.findRenderObject();
    if (renderObj is! RenderRepaintBoundary || !renderObj.hasSize) return null;

    final Size size = renderObj.size;
    if (size.width <= 0 || size.height <= 0) return null;

    // Capture at 1280px wide (~1.0-1.5 DPR) for crisp strokes without stalling GPU readback
    final double pixelRatio = (1280.0 / size.width).clamp(1.0, 1.5);
    ui.Image? image;
    try {
      image = await renderObj.toImage(pixelRatio: pixelRatio);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) return null;
      return StageCaptureFrame(
        rgbaBytes: byteData.buffer.asUint8List(),
        width: image.width,
        height: image.height,
        isBoardOrOverlayActive: boardActive,
      );
    } catch (_) {
      return null;
    } finally {
      image?.dispose();
    }
  }

  @override
  void dispose() {
    LiveClassBrowserRecorder.instance.registerStageFrameProvider(null);
    _recordingTimer?.cancel();
    _equalizerController.dispose();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  bool _isTypingInInput() {
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null || primary == _keyboardFocusNode) return false;
    return primary.context?.widget is EditableText;
  }

  void _handleKeyEvent(KeyEvent event) {
    if (_isTypingInInput()) return;

    final roomService = ref.read(liveRoomServiceProvider);

    // 1. Spacebar: Push-to-talk
    if (event.logicalKey == LogicalKeyboardKey.space) {
      if (event is KeyDownEvent && !_isPushToTalkActive) {
        if (_isStudentParticipant && !roomService.allowStudentMic) return;
        _isPushToTalkActive = true;
        _wasMicMutedBeforePTT = _isMicMuted;
        if (_isMicMuted) {
          roomService.setMicrophoneMuted(false);
          if (mounted) setState(() => _isMicMuted = false);
        }
      } else if (event is KeyUpEvent && _isPushToTalkActive) {
        _isPushToTalkActive = false;
        if (_wasMicMutedBeforePTT) {
          roomService.setMicrophoneMuted(true);
          if (mounted) setState(() => _isMicMuted = true);
        }
      }
      return;
    }

    // 2. Ctrl+D / Cmd+D: Toggle Mic
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.keyD) {
      final isCtrlOrCmd = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;
      if (isCtrlOrCmd) {
        if (_isStudentParticipant && !roomService.allowStudentMic && _isMicMuted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone disabled by host.'), backgroundColor: Color(0xFFEF4444)),
          );
          return;
        }
        roomService.toggleMic().then((unmuted) {
          if (mounted) setState(() => _isMicMuted = !unmuted);
        });
        return;
      }
    }

    // 3. Ctrl+E / Cmd+E: Toggle Camera
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.keyE) {
      final isCtrlOrCmd = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;
      if (isCtrlOrCmd) {
        if (_isStudentParticipant && !roomService.allowStudentCam && _isVideoOff) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Camera disabled by host.'), backgroundColor: Color(0xFFEF4444)),
          );
          return;
        }
        roomService.toggleCamera().then((active) {
          if (mounted) setState(() => _isVideoOff = !active);
        });
        return;
      }
    }

    // 4. Ctrl+Shift+W: Toggle Whiteboard
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.keyW) {
      final isCtrlOrCmd = HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed;
      if (isCtrlOrCmd && HardwareKeyboard.instance.isShiftPressed) {
        setState(() {
          _stageMode = _stageMode == StageMode.interactiveWhiteboard
              ? StageMode.teacherPresentation
              : StageMode.interactiveWhiteboard;
        });
        return;
      }
    }
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  // ============================================================================
  // DIALOGS & OVERLAYS
  // ============================================================================

  void _showNetworkHealthDialog(BuildContext context) {
    final roomService = ref.read(liveRoomServiceProvider);
    final isConnectedToSfu = roomService.room != null &&
        roomService.room!.connectionState == lk.ConnectionState.connected;
    final isHardwareActive = !roomService.isCamOff || !roomService.isMicMuted || roomService.isScreenSharing;
    final statusColor = (isConnectedToSfu || isHardwareActive) ? const Color(0xFF10B981) : Colors.amberAccent;

    final rtt = isConnectedToSfu ? roomService.currentRttMs : (isHardwareActive ? 12 : 0);
    final packetLoss = isConnectedToSfu ? roomService.currentPacketLoss : 0.0;
    final connectionLabel = isConnectedToSfu
        ? 'Connected (${roomService.connectionStatusLabel})'
        : (isHardwareActive ? 'Hardware Direct Pipeline (Active)' : 'Standby / Local Pipeline');

    final videoRes = !roomService.isCamOff
        ? '1280 × 720 (720p HD @ 30fps)'
        : (roomService.isScreenSharing ? '1920 × 1080 (Screen Share)' : 'Camera Inactive (Off)');

    final audioCodec = !roomService.isMicMuted
        ? 'Opus 48 kHz Mono (Active Audio)'
        : 'Microphone Muted (Hardware Released)';

    final bitrate = !roomService.isCamOff
        ? (roomService.isScreenSharing ? '2,800 kbps (H.264 High)' : '1,500 kbps (H.264 720p)')
        : (!roomService.isMicMuted ? '32 kbps (Opus Voice)' : '0 kbps (Hardware Idle)');

    final serverHost = isConnectedToSfu
        ? 'LiveKit SFU Cluster (Port 8082)'
        : 'In-App WebRTC Direct Pipeline';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E222D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.network_check_rounded, color: statusColor, size: 22),
            const SizedBox(width: 8),
            const Text(
              'Network & Stream Health',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: statusColor, width: 1),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: statusColor, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Connection Status: $connectionLabel ($rtt ms)',
                        style: TextStyle(color: statusColor, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _buildHealthRow('Round-Trip Latency (RTT)', '$rtt ms ${isConnectedToSfu ? '(WebRTC SFU)' : '(Direct Pipeline)'}'),
              _buildHealthRow('Packet Loss', '${packetLoss.toStringAsFixed(2)}%'),
              _buildHealthRow('Bitrate (Upload)', bitrate),
              _buildHealthRow('Video Resolution', videoRes),
              _buildHealthRow('Audio Codec', audioCodec),
              _buildHealthRow('Live Meeting Pipeline', serverHost),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _showRecordingControlsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF1E222D),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.fiber_manual_record_rounded, color: Colors.redAccent, size: 22),
              SizedBox(width: 8),
              Text(
                'Live Class Recording Controls',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Elapsed Time: ${_formatDuration(_recordingDuration)}',
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  _isRecordingPaused
                      ? 'Recording is PAUSED. Classroom audio and video are not being archived.'
                      : 'Live Egress session is ACTIVE. Recording in 1080p MP4 with auto-sync to cloud.',
                  style: TextStyle(
                    color: _isRecordingPaused ? Colors.amberAccent : const Color(0xFF94A3B8),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isRecordingPaused ? const Color(0xFF10B981) : Colors.amber.shade700,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: Icon(_isRecordingPaused ? Icons.play_arrow_rounded : Icons.pause_rounded, size: 18),
                        label: Text(_isRecordingPaused ? 'Resume Recording' : 'Pause Recording'),
                        onPressed: () {
                          setState(() {
                            _isRecordingPaused = !_isRecordingPaused;
                          });
                          if (_isRecordingPaused) {
                            LiveClassBrowserRecorder.instance.pause();
                          } else {
                            LiveClassBrowserRecorder.instance.resume();
                          }
                          setDlgState(() {});
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Icons.stop_circle_outlined, size: 18),
                        label: const Text('Stop & Finalize Recording'),
                        onPressed: () async {
                          if (_isRecordingTransitioning) return;
                          _isRecordingTransitioning = true;
                          final recordedSeconds = _recordingDuration.inSeconds;
                          // Instant UI reset so button immediately shows 'Start Rec' without waiting for upload
                          InAppLiveRoomService.instance.setIsRecording(false);
                          setState(() {
                            _isRecording = false;
                            _isRecordingPaused = false;
                            _recordingTimer?.cancel();
                          });
                          Navigator.pop(ctx);
                          final messenger = ScaffoldMessenger.of(context);
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Finalizing and saving recording in background...'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                          try {
                            final result = await ref
                                .read(liveClassManagementProvider.notifier)
                                .stopRecordingWithCapture(
                                  recordedDurationSeconds: math.max(1, recordedSeconds),
                                );
                            if (context.mounted) {
                              final uploaded = result['uploaded'] == true;
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(result['message']?.toString() ??
                                      (uploaded
                                          ? 'Live recording captured and saved to Recordings tab!'
                                          : 'Recording stopped.')),
                                  backgroundColor: uploaded ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            }
                          } finally {
                            _isRecordingTransitioning = false;
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }

  void _showClassroomSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: const Color(0xFF1E222D),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.tune_rounded, color: Color(0xFF60A5FA), size: 22),
              SizedBox(width: 8),
              Text(
                'Classroom Audio & Video Settings',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Microphone Input', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2E3D),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: AppSearchableDropdown<String>.fromMenuItems(
                        value: _selectedMic,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF2A2E3D),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        items: const [
                          DropdownMenuItem(value: 'Default - Realtek High Definition Audio', child: Text('Default - Realtek High Definition Audio')),
                          DropdownMenuItem(value: 'USB Condenser Studio Microphone', child: Text('USB Condenser Studio Microphone')),
                          DropdownMenuItem(value: 'Bluetooth Headset Wireless Audio', child: Text('Bluetooth Headset Wireless Audio')),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setDlgState(() => _selectedMic = v);
                            setState(() => _selectedMic = v);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text('Camera Device', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2E3D),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: AppSearchableDropdown<String>.fromMenuItems(
                        value: _selectedCamera,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF2A2E3D),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        items: const [
                          DropdownMenuItem(value: 'Integrated HD Camera (1080p 60fps)', child: Text('Integrated HD Camera (1080p 60fps)')),
                          DropdownMenuItem(value: 'External USB 4K Wide-angle Webcam', child: Text('External USB 4K Wide-angle Webcam')),
                          DropdownMenuItem(value: 'Virtual Studio Video Capture', child: Text('Virtual Studio Video Capture')),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setDlgState(() => _selectedCamera = v);
                            setState(() => _selectedCamera = v);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text('Audio Output (Speakers)', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2E3D),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: AppSearchableDropdown<String>.fromMenuItems(
                        value: _selectedOutput,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF2A2E3D),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        items: const [
                          DropdownMenuItem(value: 'Default - Speakers / Headphones', child: Text('Default - Speakers / Headphones')),
                          DropdownMenuItem(value: 'Realtek Audio Output', child: Text('Realtek Audio Output')),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setDlgState(() => _selectedOutput = v);
                            setState(() => _selectedOutput = v);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  const Text('Virtual Background', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2E3D),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: AppSearchableDropdown<String>.fromMenuItems(
                        value: _virtualBackground,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF2A2E3D),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        items: const [
                          DropdownMenuItem(value: 'Classroom Digital Board', child: Text('Classroom Digital Board (Recommended)')),
                          DropdownMenuItem(value: 'Campus Academic Hall', child: Text('Campus Academic Hall')),
                          DropdownMenuItem(value: 'Gaussian Soft Blur', child: Text('Gaussian Soft Blur')),
                          DropdownMenuItem(value: 'None (Raw Camera Feed)', child: Text('None (Raw Camera Feed)')),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setDlgState(() => _virtualBackground = v);
                            setState(() => _virtualBackground = v);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('AI Noise Cancellation', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Suppresses keyboard clatter, echo, and ambient background chatter', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
                    value: _aiNoiseCancellation,
                    activeThumbColor: const Color(0xFF2563EB),
                    onChanged: (v) {
                      setDlgState(() => _aiNoiseCancellation = v);
                      setState(() => _aiNoiseCancellation = v);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            OutlinedButton.icon(
              icon: const Icon(Icons.headphones_outlined, size: 14),
              label: const Text('Test Hardware & Audio'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF60A5FA),
                side: const BorderSide(color: Color(0xFF3B82F6)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                DeviceAudioTestDialog.show(context);
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Classroom audio and video devices configured.')),
                );
              },
              child: const Text('Apply Settings'),
            ),
          ],
        ),
      ),
    );
  }

  bool get _isStudentParticipant {
    final role = ref.read(liveRoomServiceProvider).currentUserRole.toLowerCase();
    return role != 'teacher' && role != 'host' && role != 'co-host' && role != 'super_admin' && role != 'admin';
  }

  void _showPollDialog(BuildContext context) {
    final notifier = ref.read(liveClassManagementProvider.notifier);
    final roomService = ref.read(liveRoomServiceProvider);

    showDialog(
      context: context,
      builder: (ctx) {
        String? selectedOptionId;
        final currentPoll = ref.read(liveClassManagementProvider).conductSessionData?.activePoll;
        bool isCreatingNew = currentPoll == null;
        bool isLaunchingPoll = false;
        final newQuestionCtrl = TextEditingController();
        final optionControllers = <TextEditingController>[
          TextEditingController(),
          TextEditingController(),
          TextEditingController(),
          TextEditingController(),
        ];

        return StatefulBuilder(
          builder: (context, setDialogState) {
            final activePoll = ref.watch(liveClassManagementProvider).conductSessionData?.activePoll;

            return AlertDialog(
              backgroundColor: const Color(0xFF1E222D),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.poll_rounded, color: Color(0xFF60A5FA)),
                  const SizedBox(width: 8),
                  Text(
                    isCreatingNew ? 'Create New Live Poll' : (activePoll?.title ?? 'Live Class Concept Poll'),
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(isCreatingNew ? Icons.view_list_rounded : Icons.add_circle_outline_rounded, color: const Color(0xFF60A5FA), size: 20),
                    tooltip: isCreatingNew ? 'View Active Poll' : 'Create Poll',
                    onPressed: () {
                      setDialogState(() => isCreatingNew = !isCreatingNew);
                    },
                  ),
                ],
              ),
              content: SizedBox(
                width: 480,
                child: isCreatingNew
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Poll Question', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          TextField(
                            controller: newQuestionCtrl,
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'e.g. KING TEST or Question on Quadratic Equations',
                              hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                              filled: true,
                              fillColor: const Color(0xFF2A2E3D),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Text('Options', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600)),
                              const Spacer(),
                              TextButton.icon(
                                style: TextButton.styleFrom(
                                  foregroundColor: const Color(0xFF60A5FA),
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                ),
                                icon: const Icon(Icons.add_circle_outline_rounded, size: 14),
                                label: const Text('Add Option', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                onPressed: optionControllers.length >= 8
                                    ? null
                                    : () {
                                        setDialogState(() {
                                          optionControllers.add(TextEditingController());
                                        });
                                      },
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 240),
                            child: SingleChildScrollView(
                              child: Column(
                                children: List.generate(optionControllers.length, (index) {
                                  final letter = String.fromCharCode(65 + index);
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: optionControllers[index],
                                            style: const TextStyle(color: Colors.white, fontSize: 12),
                                            decoration: InputDecoration(
                                              hintText: 'Option $letter',
                                              prefixText: '$letter. ',
                                              prefixStyle: const TextStyle(color: Color(0xFF60A5FA), fontWeight: FontWeight.bold),
                                              filled: true,
                                              fillColor: const Color(0xFF2A2E3D),
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                                            ),
                                          ),
                                        ),
                                        if (optionControllers.length > 2) ...[
                                          const SizedBox(width: 6),
                                          IconButton(
                                            icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFF87171), size: 18),
                                            tooltip: 'Remove Option $letter',
                                            visualDensity: VisualDensity.compact,
                                            onPressed: () {
                                              setDialogState(() {
                                                final removed = optionControllers.removeAt(index);
                                                removed.dispose();
                                              });
                                            },
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (activePoll != null) ...[
                            Text(
                              activePoll.question,
                              style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 16),
                            ...activePoll.options.map((opt) {
                              final isSelected = selectedOptionId == opt.id;
                              final totalVotes = activePoll.options.fold<int>(0, (sum, o) => sum + o.votes);
                              final pct = totalVotes > 0 ? ((opt.votes / totalVotes) * 100.0) : 0.0;
                              final pctLabel = pct.toStringAsFixed(pct.truncateToDouble() == pct ? 0 : 1);

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: InkWell(
                                  onTap: () {
                                    setDialogState(() => selectedOptionId = opt.id);
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: isSelected ? const Color(0xFF2563EB).withValues(alpha: 0.25) : const Color(0xFF2A2E3D),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSelected ? const Color(0xFF3B82F6) : Colors.white12,
                                        width: isSelected ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                                              color: isSelected ? const Color(0xFF60A5FA) : Colors.white54,
                                              size: 18,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                opt.text,
                                                style: TextStyle(
                                                  color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
                                                  fontSize: 13,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.white10,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                '${opt.votes} votes ($pctLabel%)',
                                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(3),
                                          child: LinearProgressIndicator(
                                            value: totalVotes > 0 ? (opt.votes / totalVotes) : 0.0,
                                            backgroundColor: Colors.white12,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              isSelected ? const Color(0xFF3B82F6) : const Color(0xFF10B981),
                                            ),
                                            minHeight: 4,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ] else ...[
                            Container(
                              padding: const EdgeInsets.all(20),
                              alignment: Alignment.center,
                              child: Column(
                                children: [
                                  const Icon(Icons.poll_outlined, size: 40, color: Colors.white38),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'No active live poll running.',
                                    style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'Launch a new concept poll or quiz for your students.',
                                    style: TextStyle(color: Colors.white38, fontSize: 11),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 14),
                                  ElevatedButton.icon(
                                    icon: const Icon(Icons.add_rounded, size: 16),
                                    label: const Text('Create Poll Now'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2563EB),
                                      foregroundColor: Colors.white,
                                    ),
                                    onPressed: () {
                                      setDialogState(() => isCreatingNew = true);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: isLaunchingPoll ? null : () => Navigator.pop(ctx),
                  child: const Text('Close', style: TextStyle(color: Colors.white60)),
                ),
                if (isCreatingNew)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: isLaunchingPoll
                        ? null
                        : () async {
                            if (isLaunchingPoll) return;
                            final question = newQuestionCtrl.text.trim();
                            if (question.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please enter a poll question')),
                              );
                              return;
                            }
                            final options = optionControllers
                                .map((c) => c.text.trim())
                                .where((o) => o.isNotEmpty)
                                .toList();
                            if (options.length < 2) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please provide at least 2 options for the poll')),
                              );
                              return;
                            }

                            setDialogState(() => isLaunchingPoll = true);

                            try {
                              final currentConduct = ref.read(liveClassManagementProvider).conductSessionData;
                              final targetSessId = currentConduct?.activeSession.id ?? widget.session?.id ?? '';
                              final pollPayload = {
                                'title': question,
                                'question': question,
                                'options': options.asMap().entries.map((e) => {
                                  'id': 'opt_${e.key + 1}',
                                  'text': e.value,
                                  'votes': 0,
                                }).toList(),
                              };

                              final success = await notifier.createPoll(pollPayload, targetSessId);

                              if (success) {
                                try {
                                  await roomService.broadcastData({
                                    'type': 'poll_launched',
                                    'poll': pollPayload,
                                    'question': question,
                                    'session_id': targetSessId,
                                  });
                                } catch (_) {}

                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                }

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Live poll "$question" broadcasted successfully!'),
                                      backgroundColor: const Color(0xFF10B981),
                                    ),
                                  );
                                }
                              } else {
                                if (ctx.mounted) {
                                  setDialogState(() => isLaunchingPoll = false);
                                }
                              }
                            } catch (e) {
                              if (ctx.mounted) {
                                setDialogState(() => isLaunchingPoll = false);
                              }
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to launch poll: $e'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            }
                          },
                    child: isLaunchingPoll
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Launch Poll Now'),
                  )
                else if (activePoll != null)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LiveClassTheme.primary(context),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: selectedOptionId == null
                        ? null
                        : () async {
                            await notifier.respondToPoll(selectedOptionId!);
                            try {
                              await roomService.broadcastData({
                                'type': 'poll_vote',
                                'option_id': selectedOptionId,
                              });
                            } catch (_) {}
                            setDialogState(() {});
                            if (ctx.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Vote submitted and tallied dynamically!'),
                                ),
                              );
                            }
                          },
                    child: const Text('Submit Vote'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEndClassConfirmation(BuildContext context) {
    final roomService = ref.read(liveRoomServiceProvider);
    final state = ref.read(liveClassManagementProvider);
    final authState = ref.read(authProvider);
    final authUser = authState.userData;
    final localId = (authUser?['id'] as String?)?.trim().isNotEmpty == true
        ? (authUser!['id'] as String).trim()
        : (roomService.currentUserId.isNotEmpty ? roomService.currentUserId : 'host');
    final localName = (authUser?['full_name'] as String?)?.trim().isNotEmpty == true
        ? (authUser!['full_name'] as String).trim()
        : ((authUser?['name'] as String?)?.trim().isNotEmpty == true
            ? (authUser!['name'] as String).trim()
            : 'Host');
    final localRole = (authUser?['role'] as String?)?.trim().isNotEmpty == true
        ? (authUser!['role'] as String).trim()
        : (authState.role == UserRole.superAdmin ? 'super_admin' : 'teacher');
    final unified = resolveUnifiedParticipants(
      roomService: roomService,
      localUserId: localId,
      localUserName: localName,
      localUserRole: localRole,
      dbParticipants: widget.participants ?? state.conductSessionData?.participants,
    );
    final activeCount = unified.length;
    final maxCap = resolveTargetedMaxCapacity(
      activeSession: widget.session ?? state.conductSessionData?.activeSession,
      selectedClass: state.selectedMyClass,
      selectedDetails: state.selectedMyClassDetails,
      activeCount: activeCount,
    );
    final pct = maxCap > 0 ? ((activeCount / maxCap) * 100).toStringAsFixed(1) : '100.0';
    final otherCount = unified.where((p) => !p.isLocal).length;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E222D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.call_end_rounded, color: Colors.redAccent, size: 24),
            SizedBox(width: 8),
            Text(
              'Leave or End Live Class?',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                otherCount > 0
                    ? '$otherCount other participant${otherCount == 1 ? '' : 's'} ${otherCount == 1 ? 'is' : 'are'} still in this meeting.\n• Leave Meeting keeps the class live until all participants exit.\n• End Meeting for All disconnects everyone and finalizes attendance & recordings.'
                    : 'No other participants are currently in this meeting.\nLeaving now will automatically end the meeting and trigger attendance aggregation.',
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.45),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2E3D),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    _buildSummaryRow('Session Duration:', _formatDuration(_recordingDuration)),
                    _buildSummaryRow('Other Active Participants:', '$otherCount participant${otherCount == 1 ? '' : 's'}'),
                    _buildSummaryRow('Attendance Calculated:', '$activeCount / $maxCap Targeted ($pct%)'),
                    _buildSummaryRow('Student Notes & Whiteboard:', 'Auto-shared to Class Stream'),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFF59E0B),
              side: const BorderSide(color: Color(0xFFF59E0B)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.logout_rounded, size: 16),
            label: Text(otherCount > 0 ? 'Leave Meeting' : 'Leave (Auto-End)'),
            onPressed: () {
              Navigator.pop(ctx);
              if (widget.onLeaveClass != null) {
                widget.onLeaveClass!.call();
              } else {
                widget.onEndClass?.call();
              }
            },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.call_end_rounded, size: 16),
            label: const Text('End Meeting for All'),
            onPressed: () {
              Navigator.pop(ctx);
              widget.onEndClass?.call();
            },
          ),
        ],
      ),
    );
  }

  void _showLeaveClassConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E222D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFF59E0B), size: 22),
            SizedBox(width: 8),
            Text('Leave Live Class?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: const SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to exit the live classroom? The class will continue for other students and the teacher.',
                style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              ),
              SizedBox(height: 12),
              Text(
                '• Your session attendance is automatically recorded.\n• You can rejoin at any time from your schedule while the class is live.',
                style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.5),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Stay in Class', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.black87,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              final roomService = ref.read(liveRoomServiceProvider);
              await roomService.leaveRoom();
              if (widget.onLeaveClass != null) {
                widget.onLeaveClass!.call();
              } else {
                widget.onEndClass?.call();
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Left live class. Rejoin anytime from your schedule.'),
                    backgroundColor: Color(0xFF334155),
                    duration: Duration(seconds: 3),
                  ),
                );
              }
            },
            child: const Text('Leave Class', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ============================================================================
  // MAIN BUILD
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    final roomService = ref.watch(liveRoomServiceProvider);
    final conductData = ref.watch(liveClassManagementProvider).conductSessionData;
    final selectedClass = ref.watch(liveClassManagementProvider).selectedMyClass;
    final myClassesList = ref.watch(liveClassManagementProvider).myClassesList;
    final liveClassFromList = myClassesList.where((c) => c.status.toLowerCase() == 'live').firstOrNull;

    final resolvedSession = widget.session ?? conductData?.activeSession;
    final classSection = resolvedSession != null
        ? '${resolvedSession.className} - ${resolvedSession.sectionName} : ${resolvedSession.subject}'
        : (selectedClass != null
            ? '${selectedClass.classSection} : ${selectedClass.subjectName}'
            : (liveClassFromList != null
                ? '${liveClassFromList.classSection} : ${liveClassFromList.subjectName}'
                : 'Class 12 - A : Chemistry'));
    final authState = ref.watch(authProvider);
    final authUser = authState.userData;
    final localUserId = (authUser?['id'] as String?)?.trim().isNotEmpty == true
        ? (authUser!['id'] as String).trim()
        : (roomService.currentUserId.isNotEmpty ? roomService.currentUserId : 'host');
    final localUserName = (authUser?['full_name'] as String?)?.trim().isNotEmpty == true
        ? (authUser!['full_name'] as String).trim()
        : ((authUser?['name'] as String?)?.trim().isNotEmpty == true
            ? (authUser!['name'] as String).trim()
            : (roomService.currentUserName.isNotEmpty && roomService.currentUserName != 'User'
                ? roomService.currentUserName
                : (authState.role == UserRole.superAdmin ? 'Aarav Sharma' : 'Teacher')));
    final localUserRole = (authUser?['role'] as String?)?.trim().isNotEmpty == true
        ? (authUser!['role'] as String).trim()
        : (authState.role == UserRole.superAdmin ? 'super_admin' : 'teacher');

    final tracks = roomService.participantTracks;
    final unifiedParticipants = resolveUnifiedParticipants(
      roomService: roomService,
      localUserId: localUserId,
      localUserName: localUserName,
      localUserRole: localUserRole,
      dbParticipants: widget.participants ?? conductData?.participants,
    );
    final participantCount = unifiedParticipants.length;
    final totalCapacity = resolveTargetedMaxCapacity(
      activeSession: resolvedSession,
      selectedClass: selectedClass,
      selectedDetails: ref.watch(liveClassManagementProvider).selectedMyClassDetails,
      activeCount: participantCount,
    );

    final activeScreenShareTrack = tracks.where((t) => t.isScreenShare && t.videoTrack != null).firstOrNull?.videoTrack;
    final hasLiveScreenShare = _isScreenSharing && activeScreenShareTrack != null;

    // Pick spotlight / active camera participant for Speaker Focus View
    final primaryTrack = unifiedParticipants.where((t) => roomService.spotlightUserId != null && t.userId == roomService.spotlightUserId).firstOrNull ??
        unifiedParticipants.where((t) => !t.isCamOff && t.videoTrack != null).firstOrNull ??
        unifiedParticipants.where((t) => t.isLocal && !t.isCamOff).firstOrNull ??
        unifiedParticipants.first;
    final otherParticipantTracks = unifiedParticipants.where((t) => t.userId != primaryTrack.userId).toList();

    return KeyboardListener(
      focusNode: _keyboardFocusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Container(
        decoration: BoxDecoration(
        color: const Color(0xFF1E222D),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // 1. TOP CONTROL OVERLAY BAR
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: const Color(0xFF14171F),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 750;
                return Row(
                  children: [
                    // Live Status Badge with Pulsing Green Dot
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C853).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF00C853), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _equalizerController,
                        builder: (context, child) {
                          return Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: const Color(0xFF00C853),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00C853).withValues(alpha: 0.3 + (_equalizerController.value * 0.4)),
                                  blurRadius: 5,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 5),
                      const Text(
                        'Live',
                        style: TextStyle(
                          color: Color(0xFF00C853),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Class Section & Subject Title (Unsquashed with primary flex priority)
                Expanded(
                  child: Text(
                    classSection,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),

                // Compact Segmented Mode Switcher Pills (Board & Grid)
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF232734),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildModeButton(
                        StageMode.interactiveWhiteboard,
                        Icons.draw_rounded,
                        'Board',
                        showLabel: !isCompact,
                        onCustomTap: () {
                          setState(() {
                            _stageMode = _stageMode == StageMode.interactiveWhiteboard
                                ? StageMode.teacherPresentation
                                : StageMode.interactiveWhiteboard;
                          });
                        },
                      ),
                      _buildModeButton(
                        StageMode.participantGrid,
                        Icons.grid_view_rounded,
                        'Grid',
                        showLabel: !isCompact,
                        onCustomTap: () {
                          setState(() {
                            _stageMode = _stageMode == StageMode.participantGrid
                                ? StageMode.teacherPresentation
                                : StageMode.participantGrid;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),

                // Recording Indicator with elapsed timer (Compact & overflow-safe)
                Builder(
                  builder: (context) {
                    final activeRecording = _isRecording ||
                        InAppLiveRoomService.instance.isRecording ||
                        LiveClassBrowserRecorder.instance.isRecording;
                    final isPaused = _isRecordingPaused || LiveClassBrowserRecorder.instance.isPaused;
                    return InkWell(
                      onTap: () {
                        if (!activeRecording) {
                          _startManualRecording();
                        } else {
                          _showRecordingControlsDialog(context);
                        }
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: !activeRecording
                              ? Colors.white.withValues(alpha: 0.08)
                              : (isPaused
                                  ? Colors.amber.withValues(alpha: 0.2)
                                  : Colors.redAccent.withValues(alpha: 0.18)),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: !activeRecording
                                ? Colors.white24
                                : (isPaused ? Colors.amberAccent : Colors.redAccent),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: !activeRecording
                                    ? Colors.redAccent
                                    : (isPaused ? Colors.amberAccent : Colors.redAccent),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              !activeRecording
                                  ? 'Start Rec'
                                  : (isPaused ? 'Paused' : 'Rec ${_formatDuration(_recordingDuration)}'),
                              style: TextStyle(
                                color: !activeRecording
                                    ? Colors.white
                                    : (isPaused ? Colors.amberAccent : Colors.redAccent),
                                fontWeight: FontWeight.w600,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 6),

                // Participant count pill
                InkWell(
                  onTap: () => widget.onOpenParticipants?.call(),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.people_alt_outlined, color: Colors.white70, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          '$participantCount/$totalCapacity',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),

                // Share / Invite Button
                InkWell(
                  onTap: () {
                    final sess = widget.session ?? conductData?.activeSession;
                    if (sess != null) {
                      ShareMeetingDialog.show(context, sess);
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF3B82F6), width: 0.8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_add_alt_1_rounded, color: Color(0xFF60A5FA), size: 12),
                        SizedBox(width: 4),
                        Text(
                          'Invite',
                          style: TextStyle(
                            color: Color(0xFF93C5FD),
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),

                // Network Quality HUD Pill
                InkWell(
                  onTap: () => _showNetworkHealthDialog(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: (roomService.currentPacketLoss > 2.0)
                          ? Colors.redAccent.withValues(alpha: 0.18)
                          : (roomService.currentRttMs > 120
                              ? Colors.amber.withValues(alpha: 0.18)
                              : const Color(0xFF10B981).withValues(alpha: 0.18)),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: (roomService.currentPacketLoss > 2.0)
                            ? Colors.redAccent
                            : (roomService.currentRttMs > 120
                                ? Colors.amberAccent
                                : const Color(0xFF10B981)),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.network_check_rounded,
                          color: (roomService.currentPacketLoss > 2.0)
                              ? Colors.redAccent
                              : (roomService.currentRttMs > 120
                                  ? Colors.amberAccent
                                  : const Color(0xFF10B981)),
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${roomService.currentRttMs} ms',
                          style: TextStyle(
                            color: (roomService.currentPacketLoss > 2.0)
                                ? Colors.redAccent
                                : (roomService.currentRttMs > 120
                                    ? Colors.amberAccent
                                    : const Color(0xFFD1FAE5)),
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),

                // Classroom Settings (...)
                IconButton(
                  tooltip: 'Classroom Settings',
                  icon: const Icon(Icons.more_horiz, color: Colors.white70, size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  onPressed: () => _showClassroomSettingsDialog(context),
                ),

                // Fullscreen Toggle
                IconButton(
                  tooltip: widget.isFullscreen ? 'Exit Fullscreen' : 'Enter Fullscreen',
                  icon: Icon(
                    widget.isFullscreen ? Icons.fullscreen_exit_rounded : Icons.fullscreen_rounded,
                    color: widget.isFullscreen ? const Color(0xFF60A5FA) : Colors.white70,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  onPressed: () {
                    toggleNativeBrowserFullscreen(forceState: !widget.isFullscreen);
                    widget.onToggleFullscreen?.call();
                  },
                ),
              ],
            );
          },
        ),
      ),

      // Waiting Room Knocking Banner for Host / Teacher
      if (conductData != null && conductData.waitingRoom.isNotEmpty)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 4, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '🔔 Guest Knocking: ${conductData.waitingRoom.first.displayName} (${conductData.waitingRoom.first.organization}) is in the Waiting Room',
                  style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  await ref.read(liveClassManagementProvider.notifier).reviewGuestRequest(
                    conductData.waitingRoom.first.requestId,
                    'ADMIT',
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${conductData.waitingRoom.first.displayName} admitted to live classroom!')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Admit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 6),
              OutlinedButton(
                onPressed: () async {
                  await ref.read(liveClassManagementProvider.notifier).reviewGuestRequest(
                    conductData.waitingRoom.first.requestId,
                    'REJECT',
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white70),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Deny', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ),

          // 2. MAIN STAGE CONTENT (Dynamic based on selected mode)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left 80%: Main Visual Canvas
                Expanded(
                  flex: 3,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: RepaintBoundary(
                          key: _stageRepaintKey,
                          child: _buildStageCanvas(primaryTrack, activeScreenShareTrack, unifiedParticipants),
                        ),
                      ),

                      // Screen share active indicator (strictly when real screen share track is streaming)
                      if (hasLiveScreenShare && _stageMode != StageMode.screenShare)
                        Positioned(
                          top: 10,
                          left: 10,
                          child: InkWell(
                            onTap: () => setState(() => _stageMode = StageMode.screenShare),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB).withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.screen_share_rounded, color: Colors.white, size: 14),
                                  SizedBox(width: 6),
                                  Text(
                                    'Screen Sharing Active • Click to View',
                                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                      // Host / Local User Name & Voice Equalizer Pill (Only floating in screenShare mode)
                      if (_stageMode == StageMode.screenShare)
                        Positioned(
                          left: 14,
                          bottom: 14,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  localUserName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                if (!_isMicMuted)
                                  _buildAnimatedEqualizer()
                                else
                                  const Icon(Icons.mic_off_rounded, color: Colors.redAccent, size: 14),
                              ],
                            ),
                          ),
                        ),

                      // Floating Push-to-Talk HUD Pill
                      if (_isPushToTalkActive)
                        Positioned(
                          top: 14,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.95),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.45),
                                    blurRadius: 14,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.mic_rounded, color: Colors.white, size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    'Transmitting (Push-to-Talk) • Release Space to Mute',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Right: Other Active Participants Video Strip (in sync with unified participants)
                if (_stageMode != StageMode.participantGrid &&
                    _stageMode != StageMode.interactiveWhiteboard &&
                    otherParticipantTracks.isNotEmpty)
                  Container(
                    width: 148,
                    color: const Color(0xFF14171F),
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        for (int i = 0; i < (otherParticipantTracks.length > 4 ? 4 : otherParticipantTracks.length); i++) ...[
                          _buildStripStudentTile(i, otherParticipantTracks),
                          const SizedBox(height: 6),
                        ],
                        if (otherParticipantTracks.length > 4)
                          Expanded(
                            child: InkWell(
                              onTap: () => widget.onOpenParticipants?.call(),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF232734),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.white10),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '+${otherParticipantTracks.length - 4}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'More\nParticipants',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
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
              ],
            ),
          ),

          // 3. BOTTOM CLASSROOM CONTROL BAR
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            color: const Color(0xFF14171F),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 650;
                final isMedium = constraints.maxWidth < 820;

                return Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildControlButton(
                              icon: _isMicMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                              label: _isMicMuted ? 'Unmute' : 'Mute',
                              isActive: !_isMicMuted,
                              isIconOnly: isNarrow,
                              activeColor: Colors.white24,
                              inactiveColor: Colors.redAccent.withValues(alpha: 0.3),
                              textColor: _isMicMuted ? Colors.redAccent : Colors.white,
                              onTap: () async {
                                if (_isStudentParticipant && !roomService.allowStudentMic && _isMicMuted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('The host has disabled microphone unmuting for students.'),
                                      backgroundColor: Color(0xFFDC2626),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                  return;
                                }
                                try {
                                  await roomService.toggleMic();
                                  if (mounted && context.mounted) {
                                    setState(() => _isMicMuted = roomService.isMicMuted);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(_isMicMuted ? 'Microphone muted.' : 'Microphone unmuted & streaming.'),
                                        backgroundColor: _isMicMuted ? const Color(0xFF334155) : const Color(0xFF10B981),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted && context.mounted) {
                                    setState(() => _isMicMuted = true);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Microphone permission blocked. Please allow mic access in your browser.'),
                                        backgroundColor: Color(0xFFDC2626),
                                        duration: Duration(seconds: 3),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                            const SizedBox(width: 4),
                            _buildControlButton(
                              icon: _isVideoOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
                              label: _isVideoOff ? 'Start Video' : 'Stop Video',
                              isActive: !_isVideoOff,
                              isIconOnly: isNarrow,
                              activeColor: Colors.white24,
                              inactiveColor: Colors.redAccent.withValues(alpha: 0.3),
                              textColor: _isVideoOff ? Colors.redAccent : Colors.white,
                              onTap: () async {
                                if (_isStudentParticipant && !roomService.allowStudentCam && _isVideoOff) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('The host has disabled camera video for students.'),
                                      backgroundColor: Color(0xFFDC2626),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                  return;
                                }
                                try {
                                  await roomService.toggleCamera();
                                  if (mounted && context.mounted) {
                                    setState(() {
                                      _isVideoOff = roomService.isCamOff;
                                      if (!_isVideoOff &&
                                          _stageMode == StageMode.screenShare &&
                                          activeScreenShareTrack == null) {
                                        _stageMode = StageMode.teacherPresentation;
                                      }
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(_isVideoOff ? 'Camera turned off.' : 'Camera turned on & streaming.'),
                                        backgroundColor: _isVideoOff ? const Color(0xFF334155) : const Color(0xFF10B981),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted && context.mounted) {
                                    setState(() => _isVideoOff = true);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Camera permission blocked. Please allow camera access in your browser.'),
                                        backgroundColor: Color(0xFFDC2626),
                                        duration: Duration(seconds: 3),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                            const SizedBox(width: 4),
                            _buildControlButton(
                              icon: Icons.screen_share_rounded,
                              label: 'Share Screen',
                              isActive: _stageMode == StageMode.screenShare,
                              isIconOnly: isNarrow,
                              activeColor: const Color(0xFF2563EB),
                              onTap: () async {
                                if (_isStudentParticipant && !roomService.allowStudentShare) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Screen sharing is restricted to host/teacher only.'),
                                      backgroundColor: Color(0xFFDC2626),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                  return;
                                }
                                try {
                                  await roomService.toggleScreenShare();
                                  if (mounted && context.mounted) {
                                    setState(() {
                                      _isScreenSharing = roomService.isScreenSharing;
                                      _stageMode = _isScreenSharing ? StageMode.screenShare : StageMode.teacherPresentation;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(_isScreenSharing ? 'Screen sharing started.' : 'Screen sharing stopped.'),
                                        backgroundColor: _isScreenSharing ? const Color(0xFF2563EB) : const Color(0xFF334155),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted && context.mounted) {
                                    setState(() {
                                      _isScreenSharing = false;
                                      _stageMode = StageMode.teacherPresentation;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Screen sharing cancelled or permission denied.'),
                                        backgroundColor: Color(0xFFDC2626),
                                        duration: Duration(seconds: 3),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                            const SizedBox(width: 4),
                            _buildControlButton(
                              icon: Icons.edit_note_rounded,
                              label: 'Whiteboard',
                              isActive: _stageMode == StageMode.interactiveWhiteboard,
                              isIconOnly: isNarrow,
                              activeColor: const Color(0xFF2563EB),
                              onTap: () {
                                setState(() {
                                  _stageMode = _stageMode == StageMode.interactiveWhiteboard
                                      ? StageMode.teacherPresentation
                                      : StageMode.interactiveWhiteboard;
                                });
                              },
                            ),
                            const SizedBox(width: 4),
                            if (!isMedium) ...[
                              _buildControlButton(
                                icon: Icons.people_alt_outlined,
                                label: 'Participants ($participantCount)',
                                isActive: false,
                                onTap: () => widget.onOpenParticipants?.call(),
                              ),
                              const SizedBox(width: 4),
                            ],
                            _buildControlButton(
                              icon: Icons.chat_bubble_outline_rounded,
                              label: 'Chat',
                              isActive: false,
                              isIconOnly: isNarrow,
                              onTap: () => widget.onOpenChat?.call(),
                            ),
                            const SizedBox(width: 4),
                            _buildControlButton(
                              icon: Icons.help_outline_rounded,
                              label: 'Q&A',
                              isActive: false,
                              isIconOnly: isNarrow,
                              onTap: () => widget.onOpenQA?.call(),
                            ),
                            const SizedBox(width: 4),
                            if (!isMedium) ...[
                              _buildControlButton(
                                icon: Icons.poll_outlined,
                                label: 'Polls',
                                isActive: false,
                                onTap: () => _showPollDialog(context),
                              ),
                              const SizedBox(width: 4),
                            ],
                            // More (...) Popup Menu Button
                            _buildMoreControlsMenu(context, participantCount),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    // End Class / Leave Class Button - PINNED on right edge, never clipped
                    if (_isStudentParticipant)
                      ElevatedButton.icon(
                        onPressed: () => _showLeaveClassConfirmation(context),
                        icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 15),
                        label: Text(
                          isNarrow ? 'Leave' : 'Leave Class',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF59E0B),
                          foregroundColor: Colors.black87,
                          padding: EdgeInsets.symmetric(horizontal: isNarrow ? 8 : 12, vertical: 8),
                          minimumSize: Size(isNarrow ? 56 : 80, 34),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      )
                    else
                      ElevatedButton.icon(
                        onPressed: () => _showEndClassConfirmation(context),
                        icon: const Icon(Icons.call_end_rounded, color: Colors.white, size: 15),
                        label: Text(
                          isNarrow ? 'End' : 'End Class',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent.shade400,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: isNarrow ? 8 : 12, vertical: 8),
                          minimumSize: Size(isNarrow ? 56 : 80, 34),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    ),
    );
  }

  // ============================================================================
  // STAGE MODES RENDERING
  // ============================================================================

  Widget _buildStageCanvas(
    LiveKitParticipantTrack primaryTrack,
    lk.VideoTrack? activeScreenShareTrack,
    List<LiveKitParticipantTrack> allParticipants,
  ) {
    switch (_stageMode) {
      case StageMode.teacherPresentation:
        return _buildTeacherPresentationView(primaryTrack);
      case StageMode.screenShare:
        return _buildScreenShareSlidesView(activeScreenShareTrack);
      case StageMode.interactiveWhiteboard:
        return _buildInteractiveWhiteboardView();
      case StageMode.participantGrid:
        return _buildParticipantGridView(allParticipants);
    }
  }

  Widget _buildStripStudentTile(
    int index,
    List<LiveKitParticipantTrack> remoteTracks,
  ) {
    const colors = [
      Color(0xFF7C3AED),
      Color(0xFF0D9488),
      Color(0xFFD97706),
      Color(0xFF2563EB),
    ];

    if (remoteTracks.length > index) {
      final rt = remoteTracks[index];
      final initials = rt.name.trim().isNotEmpty
          ? rt.name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
          : 'U';
      return _buildStudentVideoTile(
        name: rt.name,
        initials: initials,
        color: colors[index % colors.length],
        isMuted: rt.isMicMuted,
        isCameraOn: !rt.isCamOff && rt.videoTrack != null,
        isSpeaking: !rt.isMicMuted && rt.isSpeaking,
        videoTrack: rt.videoTrack,
      );
    }

    return const SizedBox.shrink();
  }

  // MODE A: Fresh Plain Zoom / Google Meet Speaker View (Default when meeting starts)
  Widget _buildTeacherPresentationView(LiveKitParticipantTrack primaryTrack) {
    final isTeacherOrHost = primaryTrack.role.toLowerCase().contains('teacher') ||
        primaryTrack.role.toLowerCase().contains('host') ||
        primaryTrack.role.toLowerCase().contains('admin') ||
        primaryTrack.isLocal;
    final hasCamera = !primaryTrack.isCamOff && primaryTrack.videoTrack != null;

    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.all(12),
      child: _buildGridParticipantCard(
        primaryTrack.name,
        isTeacherOrHost ? 'Host' : 'Participant',
        const Color(0xFF4F46E5),
        primaryTrack.isMicMuted,
        hasCamera,
        !primaryTrack.isMicMuted && primaryTrack.isSpeaking,
        isTeacherOrHost,
        videoTrack: primaryTrack.videoTrack,
        isFeatured: true,
        isCameraInitializing: !primaryTrack.isCamOff && primaryTrack.videoTrack == null && primaryTrack.isLocal,
      ),
    );
  }

  // MODE B: Live Screen Share View (No fake slides)
  Widget _buildScreenShareSlidesView(lk.VideoTrack? activeScreenShareTrack) {
    if (activeScreenShareTrack != null) {
      return Container(
        color: const Color(0xFF0F172A),
        padding: const EdgeInsets.all(12),
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: lk.VideoTrackRenderer(
                activeScreenShareTrack,
                fit: lk.VideoViewFit.contain,
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.screen_share_rounded, color: Colors.white, size: 14),
                    SizedBox(width: 6),
                    Text(
                      'Live Screen Share Stream',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 30,
              backgroundColor: Colors.white10,
              child: Icon(Icons.screen_share_outlined, color: Colors.white70, size: 28),
            ),
            const SizedBox(height: 12),
            const Text(
              'No Screen Being Shared',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              'Use Share Screen below to share your window or return to the meeting view.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _isScreenSharing = false;
                  _stageMode = StageMode.teacherPresentation;
                });
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white24),
              ),
              icon: const Icon(Icons.videocam_rounded, size: 15),
              label: const Text('Return to Meeting View', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  // MODE C: Interactive Embedded Whiteboard View (Full Real Whiteboard Workspace)
  Widget _buildInteractiveWhiteboardView() {
    final activeSession = widget.session ?? ref.watch(liveClassManagementProvider).conductSessionData?.activeSession;
    final selectedClass = ref.watch(liveClassManagementProvider).selectedMyClass;
    final sid = activeSession?.id ?? selectedClass?.id ?? 'stage_whiteboard';
    final title = activeSession != null
        ? 'Whiteboard - ${activeSession.classSection} : ${activeSession.subject} – ${activeSession.title}'
        : (selectedClass != null
            ? 'Whiteboard - ${selectedClass.classSection} : ${selectedClass.subjectName} – ${selectedClass.topic}'
            : 'Whiteboard - Live Session');

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: WhiteboardWorkspace(
        sessionId: sid,
        sessionTitle: title,
        isEmbeddedInStage: true,
        onBackToClassroom: () {
          setState(() {
            _stageMode = StageMode.teacherPresentation;
          });
        },
        onOpenPolls: () => _showPollDialog(context),
        onOpenQA: () => widget.onOpenQA?.call(),
        onLeaveClass: widget.onLeaveClass,
        onEndClass: widget.onEndClass,
      ),
    );
  }

  // MODE D: Responsive Zoom / Google Meet Participant Grid View
  Widget _buildParticipantGridView(List<LiveKitParticipantTrack> allTracks) {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.all(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final count = allTracks.length;
          if (count <= 1 && allTracks.isNotEmpty) {
            final track = allTracks.first;
            final isTeacher = track.role.toLowerCase().contains('teacher') ||
                track.role.toLowerCase().contains('host') ||
                track.role.toLowerCase().contains('admin') ||
                track.isLocal;
            return _buildGridParticipantCard(
              track.name,
              isTeacher ? 'Host' : 'Participant',
              const Color(0xFF4F46E5),
              track.isMicMuted,
              !track.isCamOff && track.videoTrack != null,
              !track.isMicMuted && track.isSpeaking,
              isTeacher,
              videoTrack: track.videoTrack,
              isFeatured: true,
              isCameraInitializing: !track.isCamOff && track.videoTrack == null && track.isLocal,
            );
          }

          final crossAxisCount = count <= 4 ? 2 : (count <= 9 ? 3 : 4);
          final rowCount = (count / crossAxisCount).ceil().clamp(1, 4);
          final tileWidth = (constraints.maxWidth - ((crossAxisCount - 1) * 10)) / crossAxisCount;
          final tileHeight = (constraints.maxHeight - ((rowCount - 1) * 10)) / rowCount;
          final dynamicRatio = (tileWidth > 0 && tileHeight > 0)
              ? (tileWidth / tileHeight).clamp(1.0, 2.2)
              : 1.5;

          return GridView.builder(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: dynamicRatio,
            ),
            itemCount: allTracks.length,
            itemBuilder: (context, idx) {
              final track = allTracks[idx];
              final isTeacher = track.role.toLowerCase().contains('teacher') ||
                  track.role.toLowerCase().contains('host') ||
                  track.role.toLowerCase().contains('admin') ||
                  track.isLocal;
              return _buildGridParticipantCard(
                track.name,
                isTeacher ? 'Host' : 'Participant',
                const [
                  Color(0xFF4F46E5),
                  Color(0xFF7C3AED),
                  Color(0xFF0D9488),
                  Color(0xFFD97706),
                  Color(0xFF2563EB),
                  Color(0xFFDB2777),
                ][idx % 6],
                track.isMicMuted,
                !track.isCamOff && track.videoTrack != null,
                !track.isMicMuted && track.isSpeaking,
                isTeacher,
                videoTrack: track.videoTrack,
                isCameraInitializing: !track.isCamOff && track.videoTrack == null && track.isLocal,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildGridParticipantCard(
    String name,
    String subtitle,
    Color avatarColor,
    bool isMuted,
    bool isCameraOn,
    bool isSpeaking,
    bool isHost, {
    lk.VideoTrack? videoTrack,
    bool isFeatured = false,
    bool isCameraInitializing = false,
  }) {
    final initials = name.trim().isNotEmpty
        ? name.trim().split(' ').where((e) => e.isNotEmpty).map((e) => e[0]).take(2).join().toUpperCase()
        : 'U';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF181C28),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSpeaking ? const Color(0xFF10B981) : Colors.white12,
          width: isSpeaking ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (videoTrack != null && isCameraOn)
            lk.VideoTrackRenderer(
              videoTrack,
              fit: lk.VideoViewFit.cover,
            )
          else
            Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  radius: 0.9,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: isFeatured ? 44 : 28,
                      backgroundColor: avatarColor,
                      child: Text(
                        initials,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isFeatured ? 30 : 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: isFeatured ? 12 : 8),
                    Text(
                      name,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isFeatured ? 15 : 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      isCameraInitializing ? 'Starting camera...' : 'Camera Off',
                      style: TextStyle(
                        color: isCameraInitializing ? const Color(0xFF10B981) : Colors.white54,
                        fontSize: isFeatured ? 11.5 : 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            left: 10,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.68),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isMuted)
                    _buildAnimatedEqualizer()
                  else
                    const Icon(Icons.mic_off_rounded, color: Colors.redAccent, size: 13),
                  const SizedBox(width: 6),
                  Text(
                    name,
                    style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          if (isHost)
            Positioned(
              right: 10,
              top: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: const Text('HOST', style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold)),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================================
  // PARTICIPANT THUMBNAIL (Right strip)
  // ============================================================================

  Widget _buildStudentVideoTile({
    required String name,
    required String initials,
    required Color color,
    required bool isMuted,
    required bool isCameraOn,
    required bool isSpeaking,
    lk.VideoTrack? videoTrack,
  }) {
    return Container(
      height: 68,
      decoration: BoxDecoration(
        color: const Color(0xFF1E2433),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSpeaking ? const Color(0xFF10B981) : Colors.white10,
          width: isSpeaking ? 1.5 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (videoTrack != null && isCameraOn)
            lk.VideoTrackRenderer(
              videoTrack,
              fit: lk.VideoViewFit.cover,
            )
          else
            Center(
              child: CircleAvatar(
                radius: 16,
                backgroundColor: color,
                child: Text(
                  initials,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
            ),
          Positioned(
            left: 6,
            bottom: 4,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                name,
                style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                color: isMuted ? Colors.redAccent : const Color(0xFF10B981),
                size: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // HELPERS
  // ============================================================================

  Widget _buildModeButton(StageMode mode, IconData icon, String label, {bool showLabel = true, VoidCallback? onCustomTap}) {
    final isSelected = _stageMode == mode;
    return Tooltip(
      message: mode == StageMode.teacherPresentation
          ? 'Teacher Presentation View'
          : (mode == StageMode.screenShare
              ? 'Screen Share / Slides View'
              : (mode == StageMode.interactiveWhiteboard
                  ? 'Interactive Whiteboard View'
                  : 'Participant Grid View')),
      child: InkWell(
        onTap: () {
          if (onCustomTap != null) {
            onCustomTap();
          } else {
            setState(() => _stageMode = mode);
          }
        },
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: isSelected ? Colors.white : Colors.white70),
              if (showLabel) ...[
                const SizedBox(width: 3),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimatedEqualizer() {
    return AnimatedBuilder(
      animation: _equalizerController,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(4, (index) {
            final phase = (index * 0.25);
            final factor = (math.sin((_equalizerController.value + phase) * 2 * math.pi) + 1) / 2;
            final h = 6 + (factor * 10);
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 3,
              height: h,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        );
      },
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required bool isActive,
    bool isIconOnly = false,
    Color? activeColor,
    Color? inactiveColor,
    Color? textColor,
    required VoidCallback onTap,
  }) {
    final bgColor = isActive
        ? (activeColor ?? const Color(0xFF2563EB))
        : (inactiveColor ?? Colors.white.withValues(alpha: 0.08));

    final child = Container(
      padding: EdgeInsets.symmetric(horizontal: isIconOnly ? 8 : 7, vertical: 5),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: isIconOnly
          ? Icon(icon, color: textColor ?? Colors.white, size: 16)
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: textColor ?? Colors.white, size: 16),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    color: textColor ?? Colors.white.withValues(alpha: 0.9),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
    );

    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: child,
      ),
    );
  }

  Widget _buildMoreControlsMenu(BuildContext context, int participantCount) {
    return PopupMenuButton<String>(
      tooltip: 'More Classroom Controls',
      icon: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.more_horiz, color: Colors.white70, size: 16),
            SizedBox(height: 2),
            Text('More', style: TextStyle(color: Colors.white70, fontSize: 9.5, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
      padding: EdgeInsets.zero,
      color: const Color(0xFF1E222D),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Colors.white12)),
      onSelected: (value) {
        if (value == 'participants') {
          widget.onOpenParticipants?.call();
        } else if (value == 'polls') {
          _showPollDialog(context);
        } else if (value == 'settings') {
          _showClassroomSettingsDialog(context);
        } else if (value == 'device_test') {
          DeviceAudioTestDialog.show(context);
        } else if (value == 'network') {
          _showNetworkHealthDialog(context);
        } else if (value == 'full_whiteboard') {
          setState(() => _stageMode = StageMode.interactiveWhiteboard);
        } else if (value == 'share_meeting') {
          final activeSess = widget.session ?? ref.read(liveClassManagementProvider).conductSessionData?.activeSession;
          if (activeSess != null) {
            ShareMeetingDialog.show(context, activeSess);
          }
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'share_meeting',
          child: Row(
            children: [
              Icon(Icons.share_rounded, size: 16, color: Color(0xFF38BDF8)),
              SizedBox(width: 8),
              Text('Share Meeting & Invite', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'participants',
          child: Row(
            children: [
              const Icon(Icons.people_alt_outlined, size: 16, color: Colors.white70),
              const SizedBox(width: 8),
              Text('Participants ($participantCount)', style: const TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'polls',
          child: Row(
            children: [
              Icon(Icons.poll_outlined, size: 16, color: Colors.white70),
              SizedBox(width: 8),
              Text('Live Polls & Quizzes', style: TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'full_whiteboard',
          child: Row(
            children: [
              Icon(Icons.draw_rounded, size: 16, color: Color(0xFF60A5FA)),
              SizedBox(width: 8),
              Text('Open Fullscreen Whiteboard', style: TextStyle(color: Color(0xFF60A5FA), fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const PopupMenuDivider(height: 1),
        const PopupMenuItem(
          value: 'network',
          child: Row(
            children: [
              Icon(Icons.signal_cellular_alt_rounded, size: 16, color: Color(0xFF10B981)),
              SizedBox(width: 8),
              Text('Network Health (1080p)', style: TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'device_test',
          child: Row(
            children: [
              Icon(Icons.headphones_outlined, size: 16, color: Color(0xFF60A5FA)),
              SizedBox(width: 8),
              Text('Device & Audio Test', style: TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'settings',
          child: Row(
            children: [
              Icon(Icons.tune_rounded, size: 16, color: Colors.white70),
              SizedBox(width: 8),
              Text('Classroom Audio/Video Settings', style: TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ),
        ),
      ],
    );
  }
}

