import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import '../models/live_class_models.dart';
import '../providers/live_class_management_provider.dart';
import '../services/in_app_live_room_service.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/role_provider.dart';
import '../../../utils/browser_fullscreen.dart';
import '../utils/live_class_theme.dart';
import '../whiteboard/widgets/whiteboard_workspace.dart';

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
  final VoidCallback? onOpenChat;
  final VoidCallback? onOpenParticipants;
  final VoidCallback? onOpenPolls;
  final VoidCallback? onOpenQA;
  final VoidCallback? onOpenWhiteboard;
  final bool isFullscreen;
  final VoidCallback? onToggleFullscreen;

  const LiveClassroomStage({
    super.key,
    this.session,
    this.participants,
    this.onEndClass,
    this.onOpenChat,
    this.onOpenParticipants,
    this.onOpenPolls,
    this.onOpenQA,
    this.onOpenWhiteboard,
    this.isFullscreen = false,
    this.onToggleFullscreen,
  });

  @override
  ConsumerState<LiveClassroomStage> createState() => _LiveClassroomStageState();
}

class _LiveClassroomStageState extends ConsumerState<LiveClassroomStage>
    with SingleTickerProviderStateMixin {
  StageMode _stageMode = StageMode.teacherPresentation;
  bool _isMicMuted = true;
  bool _isVideoOff = true;
  bool _isScreenSharing = false;
  bool _isWhiteboardActive = false;
  bool _isRecording = true;
  bool _isRecordingPaused = false;
  Duration _recordingDuration = const Duration(minutes: 18, seconds: 24);
  Timer? _recordingTimer;

  // Slide Deck State
  int _currentSlideIndex = 0;
  bool _isLaserPointerActive = false;
  Offset _laserPosition = const Offset(200, 150);

  // Embedded Whiteboard Canvas State
  final List<List<Offset>> _whiteboardStrokes = [];
  final List<Color> _strokeColors = [];
  final List<double> _strokeWidths = [];
  List<Offset> _currentStroke = [];
  Color _selectedColor = const Color(0xFF60A5FA);
  final double _selectedWidth = 3.0;
  String _selectedTool = 'pen'; // 'pen', 'highlighter', 'eraser'
  bool _isLessonBoardActive = true;

  // Audio Equalizer Animation
  late AnimationController _equalizerController;

  // Classroom Settings
  String _selectedMic = 'Default - Realtek High Definition Audio';
  String _selectedCamera = 'Integrated HD Camera (1080p 60fps)';
  String _selectedOutput = 'Default - Speakers / Headphones';
  String _virtualBackground = 'Classroom Digital Board';
  bool _aiNoiseCancellation = true;

  @override
  void initState() {
    super.initState();
    _startRecordingTimer();
    _equalizerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoConnectLiveRoom();
    });
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
              : (authState.role == UserRole.superAdmin ? 'King Doe' : 'Teacher'));
      final currentUserRole = (authUser?['role'] as String?)?.trim().isNotEmpty == true
          ? (authUser!['role'] as String).trim()
          : (authState.role == UserRole.superAdmin ? 'super_admin' : 'teacher');

      final conductData = ref.read(liveClassManagementProvider).conductSessionData;
      final sess = widget.session ?? conductData?.activeSession;
      final roomId = sess?.id ?? 'e75e144c-c754-482b-9f7a-276a743c6c5e';

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

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _equalizerController.dispose();
    super.dispose();
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E222D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.network_check_rounded, color: Color(0xFF10B981), size: 22),
            SizedBox(width: 8),
            Text(
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
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF10B981), width: 1),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Connection Status: Excellent (Stable 60 FPS)',
                        style: TextStyle(color: Color(0xFFD1FAE5), fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _buildHealthRow('Bitrate (Upload)', '3,450 kbps (Adaptive H.264)'),
              _buildHealthRow('Round-Trip Latency (RTT)', '24 ms (Optimized)'),
              _buildHealthRow('Packet Loss', '0.01% (Zero audible jitter)'),
              _buildHealthRow('Video Resolution', '1920 × 1080 (1080p Full HD)'),
              _buildHealthRow('Audio Codec', 'Opus 48 kHz Stereo (FullBand)'),
              _buildHealthRow('LiveKit Edge Server', 'AP-South-1 (Mumbai Gateway)'),
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
                          setDlgState(() {});
                          ref.read(liveClassManagementProvider.notifier).toggleRecording();
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
                        onPressed: () {
                          setState(() {
                            _isRecording = false;
                          });
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Recording finalized and queued for transcoding.')),
                          );
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
                      child: DropdownButton<String>(
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
                      child: DropdownButton<String>(
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
                      child: DropdownButton<String>(
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
                      child: DropdownButton<String>(
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
                              final success = await notifier.createPoll({
                                'title': question,
                                'question': question,
                                'options': options.asMap().entries.map((e) => {
                                  'id': 'opt_${e.key + 1}',
                                  'text': e.value,
                                }).toList(),
                              });

                              if (success) {
                                try {
                                  await roomService.broadcastData({
                                    'type': 'poll_launched',
                                    'question': question,
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E222D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.call_end_rounded, color: Colors.redAccent, size: 24),
            SizedBox(width: 8),
            Text('End Live Class for All?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ending this session will disconnect all 42 participants and automatically trigger attendance aggregation and cloud recording processing.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
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
                    _buildSummaryRow('Attendance Calculated:', '42 / 45 Students (93.3%)'),
                    _buildSummaryRow('Recording Upload:', 'Cloud Storage Transcode Queued'),
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
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              widget.onEndClass?.call();
            },
            child: const Text('End Class for All'),
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

    final classSection = widget.session != null
        ? '${widget.session!.className} - ${widget.session!.sectionName} : ${widget.session!.subject}'
        : (conductData != null
            ? '${conductData.activeSession.className} - ${conductData.activeSession.sectionName} : ${conductData.activeSession.subject}'
            : 'Class 10 - A : Mathematics');
    final authState = ref.watch(authProvider);
    final authUser = authState.userData;
    final localUserName = (authUser?['full_name'] as String?)?.trim().isNotEmpty == true
        ? (authUser!['full_name'] as String).trim()
        : ((authUser?['name'] as String?)?.trim().isNotEmpty == true
            ? (authUser!['name'] as String).trim()
            : (roomService.currentUserName.isNotEmpty
                ? roomService.currentUserName
                : (authState.role == UserRole.superAdmin ? 'King Doe' : 'Teacher')));
    final tracks = roomService.participantTracks;
    final participantCount = roomService.isConnected
        ? tracks.where((t) => !t.isScreenShare).length
        : (widget.session?.viewerCount ?? conductData?.activeSession.viewerCount ?? 1);
    final totalCapacity = widget.session?.maxParticipants ?? conductData?.activeSession.maxParticipants ?? 45;

    final localTrack = tracks.where((t) => t.isLocal && !t.isScreenShare).firstOrNull;
    final teacherTrack = tracks.where((t) => t.role.toLowerCase().contains('teacher') && !t.isScreenShare).firstOrNull;
    final activeCamTrack = (localTrack?.videoTrack != null && !localTrack!.isCamOff)
        ? localTrack.videoTrack
        : (teacherTrack?.videoTrack != null && !teacherTrack!.isCamOff ? teacherTrack.videoTrack : null);
    final activeScreenShareTrack = tracks.where((t) => t.isScreenShare && t.videoTrack != null).firstOrNull?.videoTrack;
    final remoteStudentTracks = tracks.where((t) => !t.isLocal && !t.isScreenShare).toList();

    return Container(
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

                // Compact Segmented Mode Switcher Pills
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
                      _buildModeButton(StageMode.teacherPresentation, Icons.videocam_rounded, 'Teacher', showLabel: !isCompact),
                      _buildModeButton(StageMode.screenShare, Icons.slideshow_rounded, 'Slides', showLabel: !isCompact),
                      _buildModeButton(StageMode.interactiveWhiteboard, Icons.draw_rounded, 'Board', showLabel: !isCompact),
                      _buildModeButton(StageMode.participantGrid, Icons.grid_view_rounded, 'Grid', showLabel: !isCompact),
                    ],
                  ),
                ),
                const SizedBox(width: 6),

                // Recording Indicator with elapsed timer (Compact & overflow-safe)
                InkWell(
                  onTap: () => _showRecordingControlsDialog(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: _isRecordingPaused
                          ? Colors.amber.withValues(alpha: 0.2)
                          : Colors.redAccent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isRecordingPaused ? Colors.amberAccent : Colors.redAccent,
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
                            color: _isRecordingPaused ? Colors.amberAccent : Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _isRecordingPaused ? 'Paused' : 'Rec ${_formatDuration(_recordingDuration)}',
                          style: TextStyle(
                            color: _isRecordingPaused ? Colors.amberAccent : Colors.redAccent,
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
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

                // Quality Signal Icon
                IconButton(
                  tooltip: 'Network & Stream Health (1080p 60fps)',
                  icon: const Icon(Icons.signal_cellular_alt_rounded, color: Color(0xFF00C853), size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  onPressed: () => _showNetworkHealthDialog(context),
                ),

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
                        child: _buildStageCanvas(localUserName, activeCamTrack, activeScreenShareTrack, tracks),
                      ),

                      // Screen share active indicator
                      if (_isScreenSharing && _stageMode != StageMode.screenShare)
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

                      // Host / Local User Name & Voice Equalizer Pill (Bottom Left)
                      if (_stageMode != StageMode.participantGrid)
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
                    ],
                  ),
                ),

                // Right: Remote Student Video Strip (Only shown when remote students are actively joined)
                if (_stageMode != StageMode.participantGrid && remoteStudentTracks.isNotEmpty)
                  Container(
                    width: 148,
                    color: const Color(0xFF14171F),
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        for (int i = 0; i < (remoteStudentTracks.length > 4 ? 4 : remoteStudentTracks.length); i++) ...[
                          _buildStripStudentTile(i, remoteStudentTracks),
                          const SizedBox(height: 6),
                        ],
                        if (remoteStudentTracks.length > 4)
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
                                      '+${remoteStudentTracks.length - 4}',
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
                                try {
                                  await roomService.toggleMic();
                                  if (mounted) {
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
                                  if (mounted) {
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
                                try {
                                  await roomService.toggleCamera();
                                  if (mounted) {
                                    setState(() => _isVideoOff = roomService.isCamOff);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(_isVideoOff ? 'Camera turned off.' : 'Camera turned on & streaming.'),
                                        backgroundColor: _isVideoOff ? const Color(0xFF334155) : const Color(0xFF10B981),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
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
                                try {
                                  await roomService.toggleScreenShare();
                                  if (mounted) {
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
                                  if (mounted) {
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
                                  _isWhiteboardActive = !_isWhiteboardActive;
                                  _stageMode = _isWhiteboardActive ? StageMode.interactiveWhiteboard : StageMode.teacherPresentation;
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

                    // End Class Button - PINNED on right edge, never clipped
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
    );
  }

  // ============================================================================
  // STAGE MODES RENDERING
  // ============================================================================

  Widget _buildStageCanvas(
    String localUserName,
    lk.VideoTrack? activeCamTrack,
    lk.VideoTrack? activeScreenShareTrack,
    List<LiveKitParticipantTrack> allTracks,
  ) {
    switch (_stageMode) {
      case StageMode.teacherPresentation:
        return _buildTeacherPresentationView(localUserName, activeCamTrack);
      case StageMode.screenShare:
        return _buildScreenShareSlidesView(activeScreenShareTrack);
      case StageMode.interactiveWhiteboard:
        return _buildInteractiveWhiteboardView();
      case StageMode.participantGrid:
        return _buildParticipantGridView(localUserName, allTracks);
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

  // MODE A: Teacher Presentation View (Digital Smartboard + Instructor View)
  Widget _buildTeacherPresentationView(String localUserName, lk.VideoTrack? activeCamTrack) {
    final conductData = ref.watch(liveClassManagementProvider).conductSessionData;
    final activeSession = widget.session ?? conductData?.activeSession;
    final subject = (activeSession?.subject.trim().isNotEmpty == true)
        ? activeSession!.subject.trim()
        : 'Biology';
    final rawTopic = (activeSession?.title.trim().isNotEmpty == true)
        ? activeSession!.title.trim()
        : ((activeSession?.description.trim().isNotEmpty == true)
            ? activeSession!.description.trim()
            : 'Interactive Digital Lesson');
    final topic = rawTopic.isNotEmpty ? rawTopic : 'Cell Biology & Living Systems';

    final subLower = subject.toLowerCase();
    final bool isBio = subLower.contains('bio') || subLower.contains('life');
    final bool isMath = subLower.contains('math') || subLower.contains('algebra') || subLower.contains('calc');
    final bool isPhys = subLower.contains('phys');
    final bool isChem = subLower.contains('chem');

    final String chapterTag = isBio
        ? '${subject.toUpperCase()} • CHAPTER 4: CELL & GENETICS'
        : (isMath
            ? '${subject.toUpperCase()} • CHAPTER 4: QUADRATIC EQUATIONS'
            : (isPhys
                ? '${subject.toUpperCase()} • CHAPTER 3: LAWS OF MOTION'
                : (isChem
                    ? '${subject.toUpperCase()} • CHAPTER 5: CHEMICAL KINETICS'
                    : '${subject.toUpperCase()} • ACTIVE CLASSROOM MODULE')));

    final String displayTopic = isBio
        ? (topic.contains('Quadratic') ? 'Cell Biology & Genetic Heritage' : topic)
        : (isMath ? (topic.contains('Cell') ? 'Quadratic Equations & Roots' : topic) : topic);

    final String conceptBox1 = isBio
        ? 'Cell Theory: Structural & functional unit of all living organisms'
        : (isMath
            ? 'ax² + bx + c = 0    (where a ≠ 0)'
            : (isPhys
                ? 'F = m·a    |    p = m·v    (Conservation of Momentum)'
                : (isChem
                    ? 'P·V = n·R·T    |    ΔG° = ΔH° - TΔS°'
                    : 'Curriculum Standard: Interactive Conceptual Synthesis')));

    final String conceptBox2 = isBio
        ? '6CO₂ + 6H₂O + Light ➔ C₆H₁₂O₆ + 6O₂ (Photosynthesis)'
        : (isMath
            ? 'x = (-b ± √(b² - 4ac)) / 2a'
            : (isPhys
                ? 'v = u + at    |    s = ut + ½at²    |    v² = u² + 2as'
                : (isChem
                    ? 'pH = -log[H⁺]    |    k = A·e^(-Ea/RT)'
                    : 'Active real-time notes synchronized with student devices')));

    final List<Map<String, dynamic>> pills = isBio
        ? [
            {'title': 'DNA Double Helix', 'label': 'A=T, G≡C Base Pairs', 'color': const Color(0xFF10B981)},
            {'title': 'Mitosis vs Meiosis', 'label': 'Diploid (2n) to Haploid (n)', 'color': const Color(0xFF3B82F6)},
            {'title': 'Cellular Respiration', 'label': 'Glucose + O₂ ➔ 36 ATP', 'color': const Color(0xFFF59E0B)},
          ]
        : (isMath
            ? [
                {'title': 'Δ > 0', 'label': 'Two Distinct Real Roots', 'color': const Color(0xFF10B981)},
                {'title': 'Δ = 0', 'label': 'One Real Repeated Root', 'color': const Color(0xFFF59E0B)},
                {'title': 'Δ < 0', 'label': 'Complex Conjugate Roots', 'color': const Color(0xFFEC4899)},
              ]
            : (isPhys
                ? [
                    {'title': 'Newton 1st Law', 'label': 'Inertia & Equilibrium', 'color': const Color(0xFF10B981)},
                    {'title': 'Newton 2nd Law', 'label': 'Rate of momentum change', 'color': const Color(0xFF3B82F6)},
                    {'title': 'Newton 3rd Law', 'label': 'Equal & opposite reaction', 'color': const Color(0xFFF59E0B)},
                  ]
                : (isChem
                    ? [
                        {'title': 'Le Chatelier', 'label': 'Dynamic System Equilibrium', 'color': const Color(0xFF10B981)},
                        {'title': 'Exothermic', 'label': 'Heat Release (ΔH < 0)', 'color': const Color(0xFFEC4899)},
                        {'title': 'Activation Energy', 'label': 'Catalyst Transition State', 'color': const Color(0xFF3B82F6)},
                      ]
                    : [
                        {'title': 'Interactive Board', 'label': 'Smart Canvas Ready', 'color': const Color(0xFF10B981)},
                        {'title': 'Student Sync', 'label': 'Real-time annotations', 'color': const Color(0xFF3B82F6)},
                        {'title': 'Active Q&A', 'label': 'Peer Collaboration', 'color': const Color(0xFFF59E0B)},
                      ])));

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF090D16)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Background Smartboard Graphic
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Digital Board Area
                Expanded(
                  flex: 5,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111827),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  chapterTag,
                                  style: const TextStyle(color: Color(0xFF60A5FA), fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const Spacer(),
                              const Icon(Icons.auto_awesome, color: Color(0xFFFBBF24), size: 16),
                              const SizedBox(width: 4),
                              const Text('Smartboard Active', style: TextStyle(color: Colors.white54, fontSize: 11)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            displayTopic,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'serif',
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 14),
                          // Primary Formula / Concept Box
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              conceptBox1,
                              style: const TextStyle(
                                color: Color(0xFFF8FAFC),
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                fontStyle: FontStyle.italic,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Secondary Solution / Concept Box
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              conceptBox2,
                              style: const TextStyle(
                                color: Color(0xFF67E8F9),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.05,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          // Concept pills (Safe horizontal scroll with NON-EXPANDED children)
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (int i = 0; i < pills.length; i++) ...[
                                  _buildSmartboardPill(
                                    pills[i]['title'] as String,
                                    pills[i]['label'] as String,
                                    pills[i]['color'] as Color,
                                  ),
                                  if (i < pills.length - 1) const SizedBox(width: 8),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Quick Board Actions
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              ActionChip(
                                avatar: const Icon(Icons.draw_rounded, size: 14, color: Color(0xFF60A5FA)),
                                label: const Text('Annotate Board', style: TextStyle(fontSize: 11, color: Colors.white)),
                                backgroundColor: const Color(0xFF1E293B),
                                side: const BorderSide(color: Color(0xFF3B82F6), width: 0.6),
                                onPressed: () => setState(() => _stageMode = StageMode.interactiveWhiteboard),
                              ),
                              ActionChip(
                                avatar: const Icon(Icons.slideshow_rounded, size: 14, color: Color(0xFF34D399)),
                                label: const Text('Present Slides', style: TextStyle(fontSize: 11, color: Colors.white)),
                                backgroundColor: const Color(0xFF1E293B),
                                side: const BorderSide(color: Color(0xFF10B981), width: 0.6),
                                onPressed: () => setState(() => _stageMode = StageMode.screenShare),
                              ),
                              ActionChip(
                                avatar: const Icon(Icons.open_in_new_rounded, size: 14, color: Color(0xFFFBBF24)),
                                label: const Text('Full Whiteboard Screen', style: TextStyle(fontSize: 11, color: Colors.white)),
                                backgroundColor: const Color(0xFF1E293B),
                                side: const BorderSide(color: Color(0xFFF59E0B), width: 0.6),
                                onPressed: () => widget.onOpenWhiteboard?.call(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Instructor Video Presentation Box
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (!_isVideoOff && activeCamTrack != null) ...[
                          // Live Webcam Video Stream via LiveKit WebRTC
                          lk.VideoTrackRenderer(
                            activeCamTrack,
                            fit: lk.VideoViewFit.cover,
                          ),
                          Positioned(
                            top: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF10B981), width: 0.8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.videocam_rounded, color: Color(0xFF10B981), size: 12),
                                  SizedBox(width: 4),
                                  Text('Live Camera • 1080p', style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            left: 8,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                localUserName,
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ] else if (!_isVideoOff) ...[
                          // Teacher Live Video Representation (Ready / connecting / fallback)
                          Container(
                            decoration: const BoxDecoration(
                              gradient: RadialGradient(
                                colors: [Color(0xFF334155), Color(0xFF0F172A)],
                                radius: 0.85,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 46,
                                  backgroundColor: const Color(0xFF4F46E5),
                                  child: Text(
                                    localUserName.isNotEmpty ? localUserName[0].toUpperCase() : 'T',
                                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  localUserName,
                                  style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Text('Live Camera • Ready & Streaming', style: TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(height: 8),
                                if (!_isMicMuted)
                                  _buildAnimatedEqualizer()
                                else
                                  const Text('Microphone Muted', style: TextStyle(color: Colors.white38, fontSize: 10)),
                              ],
                            ),
                          ),
                        ] else ...[
                          // Camera Off Placeholder
                          Container(
                            color: const Color(0xFF0F172A),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const CircleAvatar(
                                  radius: 36,
                                  backgroundColor: Colors.white10,
                                  child: Icon(Icons.videocam_off_rounded, color: Colors.white54, size: 36),
                                ),
                                const SizedBox(height: 10),
                                Text(localUserName, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                const Text('Camera is Turned Off', style: TextStyle(color: Colors.white70, fontSize: 11)),
                                const SizedBox(height: 10),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2563EB),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                                    minimumSize: Size.zero,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  icon: const Icon(Icons.videocam_rounded, size: 14),
                                  onPressed: () async {
                                    setState(() => _isVideoOff = false);
                                    await ref.read(liveRoomServiceProvider).toggleCamera();
                                  },
                                  label: const Text('Turn On Camera', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartboardPill(String title, String label, Color col) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: col.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: col.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: TextStyle(color: col, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 9), maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  // MODE B: Live Screen Share Presentation Slide Deck View
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
                      'Live Screen Share Stream • 1080p 60fps',
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

    final slides = [
      {
        'title': 'Slide 1: Definition & Standard Form',
        'subtitle': 'A second-order polynomial equation in a single variable x',
        'content': 'ax² + bx + c = 0,   where a ≠ 0',
        'points': [
          '• a is the quadratic coefficient (determines parabola width and orientation)',
          '• b is the linear coefficient (shifts the vertex horizontally and vertically)',
          '• c is the constant term (represents the y-intercept at x = 0)',
        ],
      },
      {
        'title': 'Slide 2: Deriving the Quadratic Formula',
        'subtitle': 'Method of Completing the Square step-by-step',
        'content': 'Divide by a: x² + (b/a)x + (c/a) = 0\n(x + b/2a)² = (b² - 4ac) / 4a²\nx = (-b ± √(b² - 4ac)) / 2a',
        'points': [
          '• Move constant term c/a to the right side of the equality',
          '• Add (b/2a)² to both sides to complete perfect square binomial',
          '• Take square root of both sides yielding the plus-or-minus radical',
        ],
      },
      {
        'title': 'Slide 3: Discriminant Analysis (Δ = b² - 4ac)',
        'subtitle': 'Predicting root nature without solving the full equation',
        'content': 'Δ = b² - 4ac',
        'points': [
          '• If Δ > 0: Graph intersects x-axis twice (Two Real Distinct Roots)',
          '• If Δ = 0: Parabola is tangent to x-axis (One Real Double Root)',
          '• If Δ < 0: Parabola never touches x-axis (Two Complex Conjugate Roots)',
        ],
      },
      {
        'title': 'Slide 4: Real-world Applications & Trajectories',
        'subtitle': 'Physics, engineering, and economics parabolic models',
        'content': 'h(t) = -½gt² + v₀t + h₀',
        'points': [
          '• Projectile trajectory calculation in aerospace and robotics',
          '• Revenue and profit maximization parabola vertex optimization',
          '• Optical focal reflector mirrors and satellite dish cross-sections',
        ],
      },
    ];

    final currentSlide = slides[_currentSlideIndex % slides.length];

    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.all(16),
      child: Stack(
        children: [
          Column(
            children: [
              // Slide Deck Header Banner (Fully responsive across all screen sizes)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isTight = constraints.maxWidth < 450;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.slideshow_rounded, color: Color(0xFF60A5FA), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isTight ? 'Quadratic Equations.pdf' : 'Presenting: Quadratic_Equations_Masterclass.pdf',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          icon: Icon(_isLaserPointerActive ? Icons.radio_button_checked : Icons.navigation_outlined, color: _isLaserPointerActive ? Colors.redAccent : Colors.white70, size: 16),
                          tooltip: _isLaserPointerActive ? 'Disable Laser Pointer' : 'Enable Laser Pointer',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                          onPressed: () {
                            setState(() => _isLaserPointerActive = !_isLaserPointerActive);
                          },
                        ),
                        const SizedBox(width: 2),
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white70, size: 12),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                          onPressed: _currentSlideIndex > 0 ? () => setState(() => _currentSlideIndex--) : null,
                        ),
                        const SizedBox(width: 2),
                        Text('${_currentSlideIndex + 1}/${slides.length}', style: const TextStyle(color: Colors.white, fontSize: 11)),
                        const SizedBox(width: 2),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 12),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                          onPressed: _currentSlideIndex < slides.length - 1 ? () => setState(() => _currentSlideIndex++) : null,
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),

              // Slide Content Area
              Expanded(
                child: MouseRegion(
                  onHover: (event) {
                    if (_isLaserPointerActive) {
                      setState(() => _laserPosition = event.localPosition);
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(currentSlide['title'] as String, style: const TextStyle(color: Color(0xFF60A5FA), fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(currentSlide['subtitle'] as String, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Text(
                              currentSlide['content'] as String,
                              style: const TextStyle(color: Color(0xFF67E8F9), fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'serif'),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ...((currentSlide['points'] as List<String>).map((pt) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                child: Text(pt, style: const TextStyle(color: Color(0xFFE2E8F0), fontSize: 13)),
                              ))),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Laser Pointer Overlay
          if (_isLaserPointerActive)
            Positioned(
              left: _laserPosition.dx - 8,
              top: _laserPosition.dy - 8,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withValues(alpha: 0.8),
                      blurRadius: 10,
                      spreadRadius: 3,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // MODE C: Interactive Embedded Whiteboard View
  Widget _buildInteractiveWhiteboardView() {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.all(10),
      child: Column(
        children: [
          // Whiteboard Toolbar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildToolIcon('pen', Icons.edit_rounded, 'Pen'),
                  _buildToolIcon('highlighter', Icons.brush_rounded, 'Highlighter'),
                  _buildToolIcon('eraser', Icons.auto_fix_normal_rounded, 'Eraser'),
                  const SizedBox(width: 8),
                  const SizedBox(height: 18, child: VerticalDivider(width: 1, color: Colors.white24)),
                  const SizedBox(width: 8),
                  _buildColorDot(const Color(0xFF60A5FA)),
                  _buildColorDot(const Color(0xFF34D399)),
                  _buildColorDot(const Color(0xFFFBBF24)),
                  _buildColorDot(const Color(0xFFF87171)),
                  _buildColorDot(Colors.white),
                  const SizedBox(width: 8),
                  const SizedBox(height: 18, child: VerticalDivider(width: 1, color: Colors.white24)),
                  const SizedBox(width: 8),
                  // Toggle between Lesson Board and Blank Canvas
                  InkWell(
                    onTap: () => setState(() => _isLessonBoardActive = !_isLessonBoardActive),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _isLessonBoardActive ? const Color(0xFF10B981).withValues(alpha: 0.18) : Colors.white10,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _isLessonBoardActive ? const Color(0xFF10B981) : Colors.white24,
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isLessonBoardActive ? Icons.menu_book_rounded : Icons.crop_square_rounded,
                            size: 13,
                            color: _isLessonBoardActive ? const Color(0xFF34D399) : Colors.white70,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _isLessonBoardActive ? 'Lesson Board' : 'Blank Board',
                            style: TextStyle(
                              color: _isLessonBoardActive ? const Color(0xFF34D399) : Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent, size: 15),
                    label: const Text('Clear', style: TextStyle(color: Colors.redAccent, fontSize: 11)),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                    ),
                    onPressed: () {
                      setState(() {
                        _whiteboardStrokes.clear();
                        _strokeColors.clear();
                        _strokeWidths.clear();
                      });
                    },
                  ),
                  const SizedBox(width: 6),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: LiveClassTheme.primary(context),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 13),
                    label: const Text('Full Whiteboard Screen', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      final activeSession = widget.session;
                      final title = activeSession != null
                          ? 'Whiteboard - ${activeSession.className} - ${activeSession.sectionName} : ${activeSession.subject}'
                          : 'Interactive Class Whiteboard';
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => WhiteboardScreen(
                            sessionId: activeSession?.id,
                            sessionTitle: title,
                            onEndClass: widget.onEndClass,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Interactive Canvas (Lesson smartboard + interactive annotation layer)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF141C2E),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Layer 1: Lesson smartboard background (Formulas, callouts, and parabola diagram)
                  if (_isLessonBoardActive)
                    _buildLessonSmartboardBackground()
                  else
                    _buildBlankCanvasGrid(),

                  // Layer 2: Interactive Custom Drawing / Annotation Canvas
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (details) {
                      setState(() {
                        _currentStroke = [details.localPosition];
                        _whiteboardStrokes.add(_currentStroke);
                        _strokeColors.add(_selectedTool == 'eraser' ? const Color(0xFF141C2E) : _selectedColor);
                        _strokeWidths.add(_selectedTool == 'eraser'
                            ? 20.0
                            : (_selectedTool == 'highlighter' ? 14.0 : _selectedWidth));
                      });
                    },
                    onPanUpdate: (details) {
                      setState(() {
                        _currentStroke.add(details.localPosition);
                      });
                    },
                    child: CustomPaint(
                      painter: _WhiteboardPainter(
                        strokes: _whiteboardStrokes,
                        colors: _strokeColors,
                        widths: _strokeWidths,
                      ),
                      size: Size.infinite,
                    ),
                  ),

                  // Bottom helper badge
                  Positioned(
                    bottom: 8,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.touch_app_rounded, color: Colors.white60, size: 12),
                          SizedBox(width: 4),
                          Text(
                            'Interactive Smartboard • Draw, annotate & teach live',
                            style: TextStyle(color: Colors.white70, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlankCanvasGrid() {
    return Container(
      color: const Color(0xFF111827),
      child: CustomPaint(
        painter: _MathGridPainter(),
        size: Size.infinite,
      ),
    );
  }

  Widget _buildLessonSmartboardBackground() {
    final conductData = ref.watch(liveClassManagementProvider).conductSessionData;
    final activeSession = widget.session ?? conductData?.activeSession;
    final subject = (activeSession?.subject.trim().isNotEmpty == true)
        ? activeSession!.subject.trim()
        : 'Biology';
    final rawTopic = (activeSession?.title.trim().isNotEmpty == true)
        ? activeSession!.title.trim()
        : ((activeSession?.description.trim().isNotEmpty == true)
            ? activeSession!.description.trim()
            : 'Interactive Digital Lesson');
    final topic = rawTopic.isNotEmpty ? rawTopic : 'Cell Biology & Living Systems';

    final subLower = subject.toLowerCase();
    final bool isBio = subLower.contains('bio') || subLower.contains('life');
    final bool isPhys = subLower.contains('phys');
    final bool isChem = subLower.contains('chem');

    final String chapterTag = isBio
        ? '${subject.toUpperCase()} • CHAPTER 4: CELL & GENETICS'
        : (isPhys
            ? '${subject.toUpperCase()} • CHAPTER 3: LAWS OF MOTION'
            : (isChem
                ? '${subject.toUpperCase()} • CHAPTER 5: CHEMICAL KINETICS'
                : '${subject.toUpperCase()} • CHAPTER 4: QUADRATIC EQUATIONS'));

    final String displayTopic = isBio
        ? (topic.contains('Quadratic') ? 'Cell Biology & Living Systems' : topic)
        : topic;

    final String box1 = isBio
        ? 'Cell Theory: Structural & functional unit of all living organisms'
        : (isPhys
            ? 'F = m·a    |    p = m·v  (Conservation of Momentum)'
            : (isChem
                ? 'P·V = n·R·T    |    ΔG° = ΔH° - TΔS°'
                : 'ax² + bx + c = 0    (where a ≠ 0)'));

    final String box2 = isBio
        ? 'Photosynthesis: 6CO₂ + 6H₂O + light ➔ C₆H₁₂O₆ + 6O₂'
        : (isPhys
            ? 'v = u + at    |    s = ut + ½at²    |    v² = u² + 2as'
            : (isChem
                ? 'pH = -log[H⁺]    |    k = A·e^(-Ea/RT)'
                : 'x = (-b ± √(b² - 4ac)) / 2a'));

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 620;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B), Color(0xFF0D1525)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Column: Key Formulas & Conditions
              Expanded(
                flex: isCompact ? 1 : 5,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFF3B82F6), width: 0.8),
                            ),
                            child: Text(
                              chapterTag,
                              style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.auto_awesome, color: Color(0xFFFBBF24), size: 14),
                          const SizedBox(width: 4),
                          const Text('Live Lesson Smartboard', style: TextStyle(color: Colors.white54, fontSize: 10.5)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        displayTopic,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Concept box 1
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          box1,
                          style: const TextStyle(
                            color: Color(0xFFF8FAFC),
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Concept box 2
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          box2,
                          style: const TextStyle(
                            color: Color(0xFF67E8F9),
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Conditions / Highlights summary
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: isBio
                              ? [
                                  const Text(
                                    'Core Biological Principles:',
                                    style: TextStyle(color: Color(0xFFFBBF24), fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  _buildDiscriminantSummary('• DNA Structure :', 'Adenine=Thymine, Guanine≡Cytosine', const Color(0xFF10B981)),
                                  _buildDiscriminantSummary('• Mitosis (2n) :', 'Identical somatic cellular division', const Color(0xFFF59E0B)),
                                  _buildDiscriminantSummary('• Meiosis (n) :', 'Genetic diversity & gamete formation', const Color(0xFFEC4899)),
                                ]
                              : [
                                  const Text(
                                    'D = b² - 4ac (Discriminant):',
                                    style: TextStyle(color: Color(0xFFFBBF24), fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  _buildDiscriminantSummary('• D > 0 :', 'Two Distinct Real Roots', const Color(0xFF10B981)),
                                  _buildDiscriminantSummary('• D = 0 :', 'One Real Repeated Root', const Color(0xFFF59E0B)),
                                  _buildDiscriminantSummary('• D < 0 :', 'Complex Conjugate Roots', const Color(0xFFEC4899)),
                                ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (!isCompact) ...[
                const SizedBox(width: 12),
                // Right Column: Diagram with dynamic Painter
                Expanded(
                  flex: 4,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0B1322),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: isBio ? _BiologyCellLessonPainter() : _ParabolaLessonPainter(),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isBio ? 'Cell Anatomy: Membrane, Nucleus & Mitochondria' : 'Parabola: y = ax² + bx + c',
                              style: TextStyle(
                                color: isBio ? const Color(0xFF34D399) : const Color(0xFFF43F5E),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildDiscriminantSummary(String prefix, String desc, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1.5),
      child: Row(
        children: [
          Text(prefix, style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Text(desc, style: const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildToolIcon(String tool, IconData icon, [String? tooltip]) {
    final isSel = _selectedTool == tool;
    final button = InkWell(
      onTap: () => setState(() => _selectedTool = tool),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isSel ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: isSel ? Colors.white : Colors.white70, size: 16),
      ),
    );
    if (tooltip != null) {
      return Tooltip(message: tooltip, child: button);
    }
    return button;
  }

  Widget _buildColorDot(Color col) {
    final isSel = _selectedColor == col && _selectedTool != 'eraser';
    return InkWell(
      onTap: () => setState(() {
        _selectedColor = col;
        if (_selectedTool == 'eraser') _selectedTool = 'pen';
      }),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 18,
        height: 18,
        decoration: BoxDecoration(
          color: col,
          shape: BoxShape.circle,
          border: Border.all(color: isSel ? Colors.white : Colors.transparent, width: 2),
        ),
      ),
    );
  }

  // MODE D: Participant Grid / Gallery View
  Widget _buildParticipantGridView(String localUserName, List<LiveKitParticipantTrack> allTracks) {
    if (allTracks.isNotEmpty) {
      return Container(
        color: const Color(0xFF0F172A),
        padding: const EdgeInsets.all(12),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.5,
          ),
          itemCount: allTracks.length,
          itemBuilder: (context, idx) {
            final track = allTracks[idx];
            final isTeacher = track.role.toLowerCase().contains('teacher') || track.isLocal;
            return _buildGridParticipantCard(
              track.name,
              isTeacher ? 'Host / Teacher' : 'Participant',
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
              !track.isMicMuted && idx == 0,
              isTeacher,
              videoTrack: track.videoTrack,
            );
          },
        ),
      );
    }

    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.all(12),
      child: GridView.count(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.5,
        children: [
          _buildGridParticipantCard(localUserName, 'Host & Presenter', const Color(0xFF4F46E5), _isMicMuted, !_isVideoOff, false, true),
        ],
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
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(10),
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
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: avatarColor,
                    child: Text(
                      name.isNotEmpty ? name.substring(0, 1) : 'U',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(name, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 10)),
                ],
              ),
            ),
          Positioned(
            left: 8,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                    color: isMuted ? Colors.redAccent : const Color(0xFF10B981),
                    size: 13,
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    isCameraOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                    color: isCameraOn ? const Color(0xFF38BDF8) : Colors.redAccent,
                    size: 13,
                  ),
                ],
              ),
            ),
          ),
          if (isHost)
            Positioned(
              right: 8,
              top: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('HOST', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
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

  Widget _buildModeButton(StageMode mode, IconData icon, String label, {bool showLabel = true}) {
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
        onTap: () => setState(() => _stageMode = mode),
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
        } else if (value == 'network') {
          _showNetworkHealthDialog(context);
        } else if (value == 'full_whiteboard') {
          widget.onOpenWhiteboard?.call();
        }
      },
      itemBuilder: (context) => [
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

class _WhiteboardPainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Color> colors;
  final List<double> widths;

  _WhiteboardPainter({
    required this.strokes,
    required this.colors,
    required this.widths,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < strokes.length; i++) {
      final stroke = strokes[i];
      if (stroke.isEmpty) continue;
      final paint = Paint()
        ..color = colors[i]
        ..strokeWidth = widths[i]
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (stroke.length == 1) {
        canvas.drawCircle(stroke[0], widths[i] / 2, paint..style = PaintingStyle.fill);
      } else {
        final path = Path();
        path.moveTo(stroke[0].dx, stroke[0].dy);
        for (int j = 1; j < stroke.length; j++) {
          path.lineTo(stroke[j].dx, stroke[j].dy);
        }
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _WhiteboardPainter oldDelegate) => true;
}

class _MathGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 1.0;

    const spacing = 24.0;
    for (double x = spacing; x < size.width; x += spacing) {
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), 0.8, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ParabolaLessonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 50 || size.height < 50) return;

    final axisPaint = Paint()
      ..color = Colors.white38
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 0.8;

    final curvePaint = Paint()
      ..color = const Color(0xFFF43F5E)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final dashedPaint = Paint()
      ..color = const Color(0xFF60A5FA).withValues(alpha: 0.5)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Grid dots/lines
    for (double x = 20; x < size.width; x += 25) {
      canvas.drawLine(Offset(x, 10), Offset(x, size.height - 10), gridPaint);
    }
    for (double y = 20; y < size.height; y += 25) {
      canvas.drawLine(Offset(10, y), Offset(size.width - 10, y), gridPaint);
    }

    final origin = Offset(size.width * 0.45, size.height * 0.60);

    // Axes
    // X Axis
    canvas.drawLine(Offset(15, origin.dy), Offset(size.width - 15, origin.dy), axisPaint);
    // Y Axis
    canvas.drawLine(Offset(origin.dx, size.height - 15), Offset(origin.dx, 15), axisPaint);

    // Axis arrowheads
    canvas.drawLine(Offset(size.width - 20, origin.dy - 4), Offset(size.width - 15, origin.dy), axisPaint);
    canvas.drawLine(Offset(size.width - 20, origin.dy + 4), Offset(size.width - 15, origin.dy), axisPaint);
    canvas.drawLine(Offset(origin.dx - 4, 20), Offset(origin.dx, 15), axisPaint);
    canvas.drawLine(Offset(origin.dx + 4, 20), Offset(origin.dx, 15), axisPaint);

    // Parabola curve: y = a(x - h)^2 + k (opens upwards)
    final h = origin.dx + 18.0;
    final k = origin.dy + 26.0; // vertex below x-axis
    const a = 0.009;

    final path = Path();
    bool started = false;
    for (double px = origin.dx - 65; px <= origin.dx + 105; px += 2) {
      final py = k - (a * (px - h) * (px - h) * 1.0);
      if (py >= 15 && py <= size.height - 10) {
        if (!started) {
          path.moveTo(px, py);
          started = true;
        } else {
          path.lineTo(px, py);
        }
      }
    }
    canvas.drawPath(path, curvePaint);

    // Axis of symmetry (dashed line through vertex x = h)
    for (double dy = 20; dy < size.height - 20; dy += 8) {
      canvas.drawLine(Offset(h, dy), Offset(h, dy + 4), dashedPaint);
    }

    // Vertex Point V(h, k)
    final vertexPaint = Paint()..color = const Color(0xFFFBBF24)..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(h, k), 3.5, vertexPaint);

    // Roots X1 and X2 (intersection with x-axis y = origin.dy)
    final diff = k - origin.dy;
    if (diff > 0 && a > 0) {
      final rootDelta = math.sqrt(diff / a);
      final x1 = h - rootDelta;
      final x2 = h + rootDelta;

      final rootPaint = Paint()..color = const Color(0xFF38BDF8)..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x1, origin.dy), 3.5, rootPaint);
      canvas.drawCircle(Offset(x2, origin.dy), 3.5, rootPaint);

      // Text labels
      final tp = TextPainter(textDirection: TextDirection.ltr);

      void drawText(String text, Offset pos, Color col, {double fontSize = 10, bool bold = false}) {
        tp.text = TextSpan(
          text: text,
          style: TextStyle(color: col, fontSize: fontSize, fontWeight: bold ? FontWeight.bold : FontWeight.normal),
        );
        tp.layout();
        tp.paint(canvas, pos);
      }

      drawText('y', Offset(origin.dx + 6, 12), Colors.white70, fontSize: 11, bold: true);
      drawText('x', Offset(size.width - 24, origin.dy + 6), Colors.white70, fontSize: 11, bold: true);
      drawText('x₁', Offset(x1 - 6, origin.dy + 5), const Color(0xFF38BDF8), fontSize: 10, bold: true);
      drawText('x₂', Offset(x2 + 2, origin.dy + 5), const Color(0xFF38BDF8), fontSize: 10, bold: true);
      drawText('Vertex', Offset(h - 14, k + 5), const Color(0xFFFBBF24), fontSize: 9.5, bold: true);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BiologyCellLessonPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 50 || size.height < 50) return;

    final membranePaint = Paint()
      ..color = const Color(0xFF10B981)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final cytoplasmPaint = Paint()
      ..color = const Color(0xFF10B981).withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    final nucleusPaint = Paint()
      ..color = const Color(0xFF3B82F6)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final nucleusFill = Paint()
      ..color = const Color(0xFF3B82F6).withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    final nucleolusPaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..style = PaintingStyle.fill;

    final mitoPaint = Paint()
      ..color = const Color(0xFFEC4899)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final riboPaint = Paint()
      ..color = const Color(0xFF67E8F9)
      ..style = PaintingStyle.fill;

    final center = Offset(size.width * 0.5, size.height * 0.5);
    final membraneRect = Rect.fromCenter(
      center: center,
      width: size.width * 0.82,
      height: size.height * 0.78,
    );

    // Cell Membrane
    final rrect = RRect.fromRectAndRadius(membraneRect, const Radius.circular(28));
    canvas.drawRRect(rrect, cytoplasmPaint);
    canvas.drawRRect(rrect, membranePaint);

    // Nucleus
    final nucleusCenter = Offset(center.dx - 18, center.dy);
    canvas.drawCircle(nucleusCenter, 28, nucleusFill);
    canvas.drawCircle(nucleusCenter, 28, nucleusPaint);

    // Nucleolus
    canvas.drawCircle(Offset(nucleusCenter.dx - 4, nucleusCenter.dy - 3), 9, nucleolusPaint);

    // Mitochondria (2 organelles)
    final mitoRect1 = Rect.fromCenter(
      center: Offset(center.dx + 42, center.dy - 24),
      width: 32,
      height: 16,
    );
    canvas.drawOval(mitoRect1, mitoPaint);

    final mitoRect2 = Rect.fromCenter(
      center: Offset(center.dx + 36, center.dy + 30),
      width: 30,
      height: 15,
    );
    canvas.drawOval(mitoRect2, mitoPaint);

    // Ribosomes (dots)
    final riboOffsets = [
      Offset(center.dx - 30, center.dy - 38),
      Offset(center.dx - 10, center.dy - 44),
      Offset(center.dx + 12, center.dy - 38),
      Offset(center.dx - 42, center.dy + 26),
      Offset(center.dx - 22, center.dy + 36),
      Offset(center.dx + 16, center.dy + 42),
    ];
    for (final off in riboOffsets) {
      canvas.drawCircle(off, 2.5, riboPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
