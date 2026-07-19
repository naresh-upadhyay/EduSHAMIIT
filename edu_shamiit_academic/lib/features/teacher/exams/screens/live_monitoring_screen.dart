import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:edu_shamiit_core/constants/app_fonts.dart';
import 'package:edu_shamiit_core/utils/responsive.dart';
import 'package:edu_shamiit_academic/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_academic/core/services/teacher_api_service.dart';

class LiveMonitoringScreen extends ConsumerStatefulWidget {
  final String examId;
  const LiveMonitoringScreen({super.key, required this.examId});

  @override
  ConsumerState<LiveMonitoringScreen> createState() =>
      _LiveMonitoringScreenState();
}

class _LiveMonitoringScreenState extends ConsumerState<LiveMonitoringScreen> {
  Timer? _pollingTimer;
  final TeacherApiService _apiService = TeacherApiService();
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;
  String? _error;

  bool _isOfflineExam = false;
  List<Map<String, dynamic>> _attendanceList = [];
  List<String> _presentStudentIds = [];
  String _searchQuery = '';
  bool _isSavingAttendance = false;

  @override
  void initState() {
    super.initState();
    _loadExamAndData();
  }

  Future<void> _loadExamAndData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final exam = await _apiService.getExam(widget.examId);
      _isOfflineExam =
          (exam['exam_type']?.toString().toLowerCase() == 'offline');

      if (_isOfflineExam) {
        final attendanceData =
            await _apiService.getExamAttendance(widget.examId);
        final studentsList = (attendanceData['data']?['students'] ??
                attendanceData['students']) as List? ??
            [];
        _attendanceList = studentsList
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _presentStudentIds = _attendanceList
            .where((s) => s['present'] == true)
            .map((s) => s['id'] as String)
            .toList();
        setState(() {
          _isLoading = false;
        });
      } else {
        await _loadSessions();
        _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
          _loadSessions();
        });
        setState(() {
          _isLoading = false;
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

  Future<void> _loadSessions() async {
    try {
      final sessionsData = await _apiService.getExamSessions(widget.examId);
      if (mounted) {
        setState(() {
          _sessions = sessionsData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted && _isLoading) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _warnStudent(String sessionId, String name) async {
    try {
      final res = await _apiService.sendProctorAction(
        widget.examId,
        sessionId,
        action: 'warn',
        message:
            '⚠️ Proctor warning: tab-switch or suspicious movements detected.',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Warning dispatched to $name.'),
            backgroundColor: Colors.orange),
      );
      if (res['success'] == true && res['data'] != null) {
        final updatedSession = res['data'] as Map<String, dynamic>;
        setState(() {
          final idx = _sessions.indexWhere((s) => s['id'] == sessionId);
          if (idx != -1) {
            _sessions[idx] = updatedSession;
          }
        });
      } else {
        _loadSessions();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to warn $name: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _pauseSession(String sessionId, String name, bool pause) async {
    try {
      final res = await _apiService.sendProctorAction(
        widget.examId,
        sessionId,
        action: pause ? 'pause' : 'resume',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                pause ? 'Exam paused for $name.' : 'Exam resumed for $name.'),
            backgroundColor: Colors.blue),
      );
      if (res['success'] == true && res['data'] != null) {
        final updatedSession = res['data'] as Map<String, dynamic>;
        setState(() {
          final idx = _sessions.indexWhere((s) => s['id'] == sessionId);
          if (idx != -1) {
            _sessions[idx] = updatedSession;
          }
        });
      } else {
        _loadSessions();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _extendTime(String sessionId, String name,
      {int extraMinutes = 15}) async {
    try {
      final res = await _apiService.sendProctorAction(
        widget.examId,
        sessionId,
        action: 'extend',
        extraMinutes: extraMinutes,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Extended duration for $name by $extraMinutes mins.'),
            backgroundColor: Colors.green),
      );
      if (res['success'] == true && res['data'] != null) {
        final updatedSession = res['data'] as Map<String, dynamic>;
        setState(() {
          final idx = _sessions.indexWhere((s) => s['id'] == sessionId);
          if (idx != -1) {
            _sessions[idx] = updatedSession;
          }
        });
      } else {
        _loadSessions();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to extend time: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _toggleForceCamera(
      String sessionId, String studentName, bool currentActive) async {
    final newActive = !currentActive;
    try {
      final channelName = 'proctor_signal_$sessionId';
      final channel = Supabase.instance.client.channel(channelName);

      channel.subscribe((status, [error]) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          channel.sendBroadcastMessage(
            event: 'force_camera',
            payload: {'enabled': newActive},
          ).then((_) {
            Supabase.instance.client.removeChannel(channel);
          });
        }
      });

      final res = await _apiService.sendProctorAction(
        widget.examId,
        sessionId,
        action: 'force_camera',
        cameraActive: newActive,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newActive
              ? 'Camera forced ON for $studentName.'
              : 'Camera forced OFF for $studentName.'),
          backgroundColor: Colors.teal,
        ),
      );

      if (res['success'] == true && res['data'] != null) {
        final updatedSession = res['data'] as Map<String, dynamic>;
        setState(() {
          final idx = _sessions.indexWhere((s) => s['id'] == sessionId);
          if (idx != -1) {
            _sessions[idx] = updatedSession;
          }
        });
      } else {
        _loadSessions();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _toggleForceMic(
      String sessionId, String studentName, bool currentActive) async {
    final newActive = !currentActive;
    try {
      final channelName = 'proctor_signal_$sessionId';
      final channel = Supabase.instance.client.channel(channelName);

      channel.subscribe((status, [error]) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          channel.sendBroadcastMessage(
            event: 'force_mic',
            payload: {'enabled': newActive},
          ).then((_) {
            Supabase.instance.client.removeChannel(channel);
          });
        }
      });

      final res = await _apiService.sendProctorAction(
        widget.examId,
        sessionId,
        action: 'force_mic',
        micActive: newActive,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newActive
              ? 'Microphone forced ON for $studentName.'
              : 'Microphone forced OFF for $studentName.'),
          backgroundColor: Colors.teal,
        ),
      );

      if (res['success'] == true && res['data'] != null) {
        final updatedSession = res['data'] as Map<String, dynamic>;
        setState(() {
          final idx = _sessions.indexWhere((s) => s['id'] == sessionId);
          if (idx != -1) {
            _sessions[idx] = updatedSession;
          }
        });
      } else {
        _loadSessions();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showCustomTimeExtensionDialog(String sessionId, String studentName) {
    final controller = TextEditingController(text: '15');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Extend Time for $studentName',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter additional duration in minutes:',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF1E293B),
                hintText: 'e.g. 15',
                hintStyle: const TextStyle(color: Colors.grey),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.teal),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () {
              final val = int.tryParse(controller.text);
              if (val != null && val > 0) {
                Navigator.pop(context);
                _extendTime(sessionId, studentName, extraMinutes: val);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Please enter a valid positive number.'),
                      backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Extend', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _forceSubmit(String sessionId, String name) async {
    try {
      final res = await _apiService.sendProctorAction(
        widget.examId,
        sessionId,
        action: 'submit',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Forced exam submission for $name.'),
            backgroundColor: Colors.blueGrey),
      );
      if (res['success'] == true && res['data'] != null) {
        final updatedSession = res['data'] as Map<String, dynamic>;
        setState(() {
          final idx = _sessions.indexWhere((s) => s['id'] == sessionId);
          if (idx != -1) {
            _sessions[idx] = updatedSession;
          }
        });
      } else {
        _loadSessions();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to submit: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _suspendStudent(String sessionId, String name) async {
    try {
      final res = await _apiService.sendProctorAction(
        widget.examId,
        sessionId,
        action: 'suspend',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('$name has been suspended.'),
            backgroundColor: Colors.red),
      );
      if (res['success'] == true && res['data'] != null) {
        final updatedSession = res['data'] as Map<String, dynamic>;
        setState(() {
          final idx = _sessions.indexWhere((s) => s['id'] == sessionId);
          if (idx != -1) {
            _sessions[idx] = updatedSession;
          }
        });
      } else {
        _loadSessions();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to suspend: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _reopenSession(String sessionId, String name) async {
    try {
      final res = await _apiService.sendProctorAction(
        widget.examId,
        sessionId,
        action: 'reopen',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Exam reopened for $name. They can now rejoin.'),
            backgroundColor: Colors.green),
      );
      if (res['success'] == true && res['data'] != null) {
        final updatedSession = res['data'] as Map<String, dynamic>;
        setState(() {
          final idx = _sessions.indexWhere((s) => s['id'] == sessionId);
          if (idx != -1) {
            _sessions[idx] = updatedSession;
          }
        });
      } else {
        _loadSessions();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to reopen exam: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          _isOfflineExam ? 'Offline Exam Attendance' : 'Live Proctoring Panel',
          style: const TextStyle(
            fontFamily: AppFonts.heading,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => safeGoBack(context, '/teacher/dashboard'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() {
                _isLoading = true;
              });
              if (_isOfflineExam) {
                _loadExamAndData();
              } else {
                _loadSessions();
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Error: $_error',
                            style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            if (_isOfflineExam) {
                              _loadExamAndData();
                            } else {
                              _loadSessions();
                            }
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : _isOfflineExam
                    ? _buildOfflineAttendanceUI()
                    : _sessions.isEmpty
                        ? const Center(
                            child: Text(
                              'No students are currently active in this exam.',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey),
                            ),
                          )
                        : Column(
                            children: [
                              _buildProctorOverviewBar(),
                              Expanded(
                                child: GridView.builder(
                                  padding: const EdgeInsets.all(16),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: Responsive.value<int>(
                                      context,
                                      mobile: 1,
                                      tablet: 2,
                                      desktop: 4,
                                    ),
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                    mainAxisExtent: 310,
                                  ),
                                  itemCount: _sessions.length,
                                  itemBuilder: (context, index) {
                                    return _buildStudentProctorCard(
                                        _sessions[index]);
                                  },
                                ),
                              ),
                            ],
                          ),
      ),
    );
  }

  Widget _buildProctorOverviewBar() {
    final activeCount = _sessions
        .where((s) => s['status'] == 'active' || s['status'] == 'online')
        .length;
    final warningCount =
        _sessions.where((s) => (s['warnings_count'] as int? ?? 0) > 0).length;
    final disconnectedCount =
        _sessions.where((s) => s['is_online'] == false).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryChip('Active', '$activeCount', Colors.green),
          _buildSummaryChip('Suspicious', '$warningCount', Colors.orange),
          _buildSummaryChip('Disconnected', '$disconnectedCount', Colors.grey),
        ],
      ),
    );
  }

  Widget _buildSummaryChip(String label, String value, Color color) {
    return Row(
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text('$label: ',
            style: const TextStyle(fontSize: 11.5, color: Colors.grey)),
        Text(value,
            style:
                const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildStudentProctorCard(Map<String, dynamic> session) {
    final warnings = session['warnings_count'] as int? ?? 0;
    final isPaused = session['is_paused'] as bool? ?? false;
    final status = session['status'] as String? ?? 'active';

    // Check dynamic last ping online latency state
    bool isOnline = session['is_online'] as bool? ?? false;
    final lastPingStr = session['last_ping'] as String?;
    if (lastPingStr != null) {
      final lastPing = DateTime.parse(lastPingStr).toUtc();
      final diff = DateTime.now().toUtc().difference(lastPing);
      if (diff.inSeconds > 25) {
        isOnline = false;
      }
    }

    final profile = session['profiles'] as Map<String, dynamic>? ?? {};
    final studentName = profile['full_name'] as String? ?? 'Student';

    Color statusColor = Colors.green;
    if (!isOnline) {
      statusColor = Colors.grey;
    } else if (status == 'suspended') {
      statusColor = Colors.red;
    } else if (warnings > 0) {
      statusColor = Colors.orange;
    }

    return Card(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: status == 'suspended'
              ? Colors.red
              : warnings > 0
                  ? Colors.red.shade200
                  : Colors.grey.shade200,
          width: warnings > 0 ? 2.0 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: statusColor, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    studentName,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildProctorDetailRow('Question Status',
                session['active_question'] != null ? 'Active' : 'N/A'),
            _buildProctorDetailRow(
                'Extra duration', '${session['extra_minutes'] ?? 0} Mins'),
            _buildProctorDetailRow('Warnings', '$warnings / 5',
                valueColor: warnings > 0 ? Colors.red : null),
            _buildProctorDetailRow(
                'Connection', isOnline ? 'Online' : 'Offline',
                valueColor: isOnline ? Colors.green : Colors.red),
            _buildProctorDetailRow('Status', status.toUpperCase(),
                valueColor: status == 'suspended' ? Colors.red : null),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildControlIconButton(
                  icon: (session['camera_active'] as bool? ?? true)
                      ? Icons.videocam
                      : Icons.videocam_off,
                  isActive: session['camera_active'] as bool? ?? true,
                  onTap: () => _toggleForceCamera(session['id'], studentName,
                      session['camera_active'] as bool? ?? true),
                  tooltip: (session['camera_active'] as bool? ?? true)
                      ? 'Camera active. Tap to force OFF.'
                      : 'Camera muted. Tap to force ON.',
                ),
                _buildControlIconButton(
                  icon: (session['mic_active'] as bool? ?? true)
                      ? Icons.mic
                      : Icons.mic_off,
                  isActive: session['mic_active'] as bool? ?? true,
                  onTap: () => _toggleForceMic(session['id'], studentName,
                      session['mic_active'] as bool? ?? true),
                  tooltip: (session['mic_active'] as bool? ?? true)
                      ? 'Mic active. Tap to force OFF.'
                      : 'Mic muted. Tap to force ON.',
                ),
                _buildControlIconButton(
                  icon: isPaused ? Icons.play_arrow : Icons.pause,
                  isActive: !isPaused,
                  onTap: () =>
                      _pauseSession(session['id'], studentName, !isPaused),
                  tooltip: isPaused
                      ? 'Exam paused. Tap to resume.'
                      : 'Exam active. Tap to pause.',
                ),
              ],
            ),
            const Spacer(),
            if (status == 'completed' || status == 'suspended') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _reopenSession(session['id'], studentName),
                  icon:
                      const Icon(Icons.refresh, size: 14, color: Colors.white),
                  label: const Text('Reopen Exam Session',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ] else ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isOnline
                      ? () => _showProctorFeedDialog(session, studentName)
                      : null,
                  icon:
                      const Icon(Icons.videocam, size: 14, color: Colors.white),
                  label: Text(
                    isOnline
                        ? 'View Live Proctor Feed'
                        : 'Student Offline / Feed Unavailable',
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isOnline
                        ? const Color(0xFFEF4444)
                        : Colors.grey.shade400,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    disabledForegroundColor: Colors.grey.shade600,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _warnStudent(session['id'], studentName),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Warn', style: TextStyle(fontSize: 11)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          _showStudentActionsDrawer(session, studentName),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child:
                          const Text('Actions', style: TextStyle(fontSize: 11)),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showProctorFeedDialog(
      Map<String, dynamic> session, String studentName) {
    showDialog(
      context: context,
      builder: (context) => _ProctorFeedDialog(
        examId: widget.examId,
        sessionId: session['id'],
        studentName: studentName,
        getSessions: () => _sessions,
        onWarn: _warnStudent,
        onPause: _pauseSession,
        onExtend: _extendTime,
        onSuspend: _suspendStudent,
        onReopen: _reopenSession,
        onToggleCamera: _toggleForceCamera,
        onToggleMic: _toggleForceMic,
      ),
    );
  }

  Widget _buildProctorDetailRow(String label, String value,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlIconButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    final activeBg = Colors.green.shade50;
    final inactiveBg = Colors.red.shade50;
    final activeColor = Colors.green.shade700;
    final inactiveColor = Colors.red.shade700;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isActive ? activeBg : inactiveBg,
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive ? Colors.green.shade200 : Colors.red.shade200,
                width: 1,
              ),
            ),
            child: Icon(
              icon,
              size: 18,
              color: isActive ? activeColor : inactiveColor,
            ),
          ),
        ),
      ),
    );
  }

  void _showStudentActionsDrawer(
      Map<String, dynamic> session, String studentName) {
    final sessionId = session['id'] as String;
    final isPaused = session['is_paused'] as bool? ?? false;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Actions for $studentName',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(isPaused ? Icons.play_arrow : Icons.pause,
                  color: Colors.orange),
              title:
                  Text(isPaused ? 'Resume Exam Session' : 'Pause Exam Session'),
              onTap: () {
                Navigator.pop(context);
                _pauseSession(sessionId, studentName, !isPaused);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_alarm, color: Colors.green),
              title: const Text('Extend Time (+15 Mins)'),
              onTap: () {
                Navigator.pop(context);
                _extendTime(sessionId, studentName, extraMinutes: 15);
              },
            ),
            ListTile(
              leading: const Icon(Icons.alarm_add, color: Colors.teal),
              title: const Text('Extend Time (Custom Duration...)'),
              onTap: () {
                Navigator.pop(context);
                _showCustomTimeExtensionDialog(sessionId, studentName);
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock_clock, color: Colors.blue),
              title: const Text('Force Submit Session'),
              onTap: () {
                Navigator.pop(context);
                _forceSubmit(sessionId, studentName);
              },
            ),
            ListTile(
              leading: const Icon(Icons.remove_circle, color: Colors.red),
              title: const Text('Suspend Student from Exam'),
              onTap: () {
                Navigator.pop(context);
                _suspendStudent(sessionId, studentName);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineAttendanceUI() {
    final filtered = _attendanceList.where((student) {
      final name = (student['full_name'] ?? '').toString().toLowerCase();
      final cls = (student['class'] ?? '').toString().toLowerCase();
      final roll = (student['roll_number'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) ||
          cls.contains(query) ||
          roll.contains(query);
    }).toList();

    final total = _attendanceList.length;
    final present = _presentStudentIds.length;
    final absent = total - present;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Row(
            children: [
              Expanded(
                  child: _buildSummaryCard(
                      'Total Students', '$total', Colors.blue)),
              const SizedBox(width: 12),
              Expanded(
                  child:
                      _buildSummaryCard('Present', '$present', Colors.green)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildSummaryCard('Absent', '$absent', Colors.red)),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search by student name, roll number, class...',
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.indigo, width: 1.5),
              ),
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.people_outline,
                          size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(
                        _searchQuery.isEmpty
                            ? 'No students assigned to this exam.'
                            : 'No students matching search criteria.',
                        style: const TextStyle(
                            color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filtered.length,
                  itemBuilder: (context, idx) {
                    final student = filtered[idx];
                    final sId = student['id'];
                    final isPresent = _presentStudentIds.contains(sId);
                    final isGraded = student['status'] == 'graded';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isPresent
                              ? Colors.green.withValues(alpha: 0.3)
                              : const Color(0xFFE2E8F0),
                          width: isPresent ? 1.5 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: isPresent
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.indigo.withValues(alpha: 0.05),
                            radius: 20,
                            child: Text(
                              (student['full_name'] ?? 'S')
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: TextStyle(
                                color: isPresent ? Colors.green : Colors.indigo,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        student['full_name'] ?? 'Student',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Color(0xFF0F172A),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (isGraded)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green
                                              .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'Graded',
                                          style: TextStyle(
                                              color: Colors.green,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Class: ${student['class'] ?? "N/A"} • Roll: ${student['roll_number'] ?? "—"}',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Switch(
                            value: isPresent,
                            activeThumbColor: Colors.green,
                            onChanged: isGraded
                                ? null
                                : (val) {
                                    setState(() {
                                      if (val) {
                                        if (!_presentStudentIds.contains(sId)) {
                                          _presentStudentIds.add(sId);
                                        }
                                      } else {
                                        _presentStudentIds.remove(sId);
                                      }
                                    });
                                  },
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isSavingAttendance ? null : _saveAttendanceData,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isSavingAttendance
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Save Attendance',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAttendanceData() async {
    setState(() {
      _isSavingAttendance = true;
    });
    try {
      await _apiService.saveExamAttendance(widget.examId, _presentStudentIds);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attendance saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      await _loadExamAndData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save attendance: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingAttendance = false;
        });
      }
    }
  }
}

class _FaceReticleOverlay extends StatefulWidget {
  const _FaceReticleOverlay();

  @override
  State<_FaceReticleOverlay> createState() => _FaceReticleOverlayState();
}

class _FaceReticleOverlayState extends State<_FaceReticleOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.85, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Outer corner bracket reticle
            Transform.scale(
              scale: _animation.value,
              child: SizedBox(
                width: 140,
                height: 140,
                child: CustomPaint(
                  painter: _ReticlePainter(color: Colors.teal.shade300),
                ),
              ),
            ),
            // Pulsing inner scanner line
            Positioned(
              top: 15 + (_animation.value * 90),
              child: Container(
                width: 110,
                height: 1.5,
                decoration: BoxDecoration(
                  color: Colors.teal.shade300,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.teal.shade300.withValues(alpha: 0.8),
                      blurRadius: 4,
                      spreadRadius: 1,
                    )
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ReticlePainter extends CustomPainter {
  final Color color;
  _ReticlePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    const double length = 15.0;

    // Top-Left Corner
    canvas.drawLine(const Offset(0, 0), const Offset(length, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, length), paint);

    // Top-Right Corner
    canvas.drawLine(
        Offset(size.width, 0), Offset(size.width - length, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, length), paint);

    // Bottom-Left Corner
    canvas.drawLine(Offset(0, size.height), Offset(length, size.height), paint);
    canvas.drawLine(
        Offset(0, size.height), Offset(0, size.height - length), paint);

    // Bottom-Right Corner
    canvas.drawLine(Offset(size.width, size.height),
        Offset(size.width - length, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height),
        Offset(size.width, size.height - length), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MicEqualizerMeter extends StatefulWidget {
  final bool isOnline;
  const _MicEqualizerMeter({required this.isOnline});

  @override
  State<_MicEqualizerMeter> createState() => _MicEqualizerMeterState();
}

class _MicEqualizerMeterState extends State<_MicEqualizerMeter> {
  final math.Random _random = math.Random();
  List<double> _heights = List.filled(15, 4.0);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.isOnline) {
      _timer = Timer.periodic(const Duration(milliseconds: 180), (timer) {
        if (widget.isOnline && mounted) {
          setState(() {
            _heights =
                List.generate(15, (index) => _random.nextDouble() * 24 + 4);
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(15, (index) {
        final double height = widget.isOnline ? _heights[index] : 4.0;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 3,
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          decoration: BoxDecoration(
            color: widget.isOnline
                ? (height > 20
                    ? Colors.redAccent
                    : (height > 12 ? Colors.orangeAccent : Colors.greenAccent))
                : Colors.grey.shade600,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}

class _ProctorFeedDialog extends StatefulWidget {
  final String examId;
  final String sessionId;
  final String studentName;
  final List<Map<String, dynamic>> Function() getSessions;
  final Future<void> Function(String sessionId, String studentName) onWarn;
  final Future<void> Function(String sessionId, String studentName, bool pause)
      onPause;
  final Future<void> Function(String sessionId, String studentName,
      {int extraMinutes}) onExtend;
  final Future<void> Function(String sessionId, String studentName) onSuspend;
  final Future<void> Function(String sessionId, String studentName) onReopen;
  final Future<void> Function(
      String sessionId, String studentName, bool currentActive) onToggleCamera;
  final Future<void> Function(
      String sessionId, String studentName, bool currentActive) onToggleMic;

  const _ProctorFeedDialog({
    required this.examId,
    required this.sessionId,
    required this.studentName,
    required this.getSessions,
    required this.onWarn,
    required this.onPause,
    required this.onExtend,
    required this.onSuspend,
    required this.onReopen,
    required this.onToggleCamera,
    required this.onToggleMic,
  });

  @override
  State<_ProctorFeedDialog> createState() => _ProctorFeedDialogState();
}

class _ProctorFeedDialogState extends State<_ProctorFeedDialog> {
  final TeacherApiService _teacherApiService = TeacherApiService();
  Room? _proctorRoom;
  RealtimeChannel? _signalingChannel;
  VideoTrack? _cameraTrack;
  VideoTrack? _screenTrack;
  Timer? _timer;
  EventsListener<RoomEvent>? _roomListener;

  @override
  void initState() {
    super.initState();
    _setupSignaling();
    _connectToLiveKit();
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted) {
        _updateTracks();
      }
    });
  }

  Future<void> _setupSignaling() async {
    final channelName = 'proctor_signal_${widget.sessionId}';
    debugPrint('[TeacherProctor] Subscribing to $channelName');

    _signalingChannel = Supabase.instance.client.channel(channelName);

    _signalingChannel!.subscribe((status, [error]) {
      debugPrint('[TeacherProctor] Supabase signaling status: $status');
      if (status == RealtimeSubscribeStatus.subscribed) {
        _sendConnectRequest();
      }
    });
  }

  void _sendConnectRequest() {
    if (_signalingChannel != null) {
      debugPrint('[TeacherProctor] Sending connect_request to student');
      _signalingChannel!.sendBroadcastMessage(
        event: 'connect_request',
        payload: {'teacher_id': 'proctor'},
      );
    }
  }

  Future<void> _connectToLiveKit() async {
    try {
      final roomName = 'proctor_session_${widget.sessionId}';
      final tokenRes = await _teacherApiService.getLiveKitToken(
        room: roomName,
        identity: 'teacher_monitor',
        name: 'Teacher Proctor',
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

      debugPrint(
          '[TeacherProctor] Connecting to LiveKit: $sfuUrl, Room: $roomName');

      _proctorRoom = Room();

      _roomListener = _proctorRoom!.createListener();
      _roomListener!.on<RoomEvent>((event) {
        debugPrint('[TeacherProctor] RoomEvent: $event');
        if (event is TrackSubscribedEvent ||
            event is TrackUnsubscribedEvent ||
            event is ParticipantConnectedEvent ||
            event is ParticipantDisconnectedEvent) {
          _updateTracks();
        }
      });

      await _proctorRoom!.connect(sfuUrl, token);

      _updateTracks();
      _sendConnectRequest();
    } catch (e) {
      debugPrint('[TeacherProctor] Connection error: $e');
    }
  }

  void _updateTracks() {
    if (_proctorRoom == null) return;

    VideoTrack? newCameraTrack;
    VideoTrack? newScreenTrack;

    for (final participant in _proctorRoom!.remoteParticipants.values) {
      for (final pub in participant.videoTrackPublications) {
        if (pub.subscribed && pub.track is VideoTrack) {
          final isCamera = pub.source == TrackSource.camera ||
              pub.name.toLowerCase().contains('camera');
          final isScreen = pub.source == TrackSource.screenShareVideo ||
              pub.name.toLowerCase().contains('screen');

          if (isCamera) {
            newCameraTrack = pub.track as VideoTrack;
          } else if (isScreen) {
            newScreenTrack = pub.track as VideoTrack;
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        _cameraTrack = newCameraTrack;
        _screenTrack = newScreenTrack;
      });
    }
  }

  void _showFeedCustomTimeExtensionDialog() {
    final controller = TextEditingController(text: '15');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Extend Time for ${widget.studentName}',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter additional duration in minutes:',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: const Color(0xFF1E293B),
                hintText: 'e.g. 15',
                hintStyle: const TextStyle(color: Colors.grey),
                enabledBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Color(0xFF334155)),
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: const BorderSide(color: Colors.teal),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () async {
              final val = int.tryParse(controller.text);
              if (val != null && val > 0) {
                Navigator.pop(context);
                await widget.onExtend(widget.sessionId, widget.studentName,
                    extraMinutes: val);
                setState(() {});
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Please enter a valid positive number.'),
                      backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Extend', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _roomListener?.dispose();
    if (_proctorRoom != null) {
      try {
        _proctorRoom!.disconnect();
      } catch (_) {}
      _proctorRoom = null;
    }
    if (_signalingChannel != null) {
      try {
        _signalingChannel!
            .sendBroadcastMessage(event: 'disconnect_request', payload: {});
        Supabase.instance.client.removeChannel(_signalingChannel!);
      } catch (_) {}
    }
    super.dispose();
  }

  Widget _buildLogLine(String time, String text,
      {bool isWarning = false, bool isInfo = false, bool isError = false}) {
    Color col = Colors.grey.shade400;
    if (isWarning) col = Colors.orange.shade400;
    if (isInfo) col = Colors.teal.shade300;
    if (isError) col = Colors.red.shade400;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$time - ',
              style: const TextStyle(
                  color: Colors.grey, fontSize: 10, fontFamily: 'Courier')),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: col,
                fontSize: 10,
                fontWeight:
                    isWarning || isError ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.getSessions().firstWhere(
          (s) => s['id'] == widget.sessionId,
          orElse: () => <String, dynamic>{},
        );

    if (session.isEmpty) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        backgroundColor: const Color(0xFF0F172A),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child:
              Text('Session not found', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    final isPaused = session['is_paused'] as bool? ?? false;
    final status = session['status'] as String? ?? 'active';
    final lastPingStr = session['last_ping'] as String?;
    bool isOnline = session['is_online'] as bool? ?? false;
    if (lastPingStr != null) {
      final lastPing = DateTime.parse(lastPingStr).toUtc();
      final diff = DateTime.now().toUtc().difference(lastPing);
      if (diff.inSeconds > 25) {
        isOnline = false;
      }
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: const Color(0xFF0F172A),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                          color: isOnline ? Colors.green : Colors.red,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (isOnline ? Colors.green : Colors.red)
                                  .withValues(alpha: 0.5),
                              blurRadius: 8,
                              spreadRadius: 2,
                            )
                          ]),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Proctor Console: ${widget.studentName}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: AppFonts.heading,
                          ),
                        ),
                        Text(
                          isOnline
                              ? '🔴 Feed Live • Streaming at 1080p'
                              : '⚪ Feed Terminated • Student Offline',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(color: Color(0xFF1E293B), height: 32),
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  alignment: WrapAlignment.center,
                  children: [
                    SizedBox(
                      width: 300,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('CAM 01 - STUDENT VIEW',
                              style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Container(
                            height: 200,
                            decoration: BoxDecoration(
                              color: const Color(0xFF020617),
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: const Color(0xFF1E293B)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Stack(
                                children: [
                                  Center(
                                    child: isOnline
                                        ? (_cameraTrack != null
                                            ? VideoTrackRenderer(
                                                _cameraTrack!,
                                                fit: VideoViewFit.cover,
                                              )
                                            : Stack(
                                                alignment: Alignment.center,
                                                children: [
                                                  const _FaceReticleOverlay(),
                                                  Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Icon(Icons.face,
                                                          size: 64,
                                                          color: Colors
                                                              .teal.shade300),
                                                      const SizedBox(
                                                          height: 12),
                                                      Text(
                                                        'FACE FOCUS LOCKED',
                                                        style: TextStyle(
                                                          color: Colors
                                                              .teal.shade300,
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ))
                                        : Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(Icons.videocam_off,
                                                  size: 64, color: Colors.grey),
                                              const SizedBox(height: 12),
                                              Text(
                                                'FEED LOST',
                                                style: TextStyle(
                                                  color: Colors.grey.shade400,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                  if (isOnline) ...[
                                    if (_cameraTrack != null)
                                      Positioned(
                                        top: 12,
                                        right: 12,
                                        child: IconButton(
                                          icon: const Icon(
                                              Icons.fullscreen_rounded,
                                              color: Colors.white,
                                              size: 20),
                                          style: IconButton.styleFrom(
                                            backgroundColor: Colors.black
                                                .withValues(alpha: 0.6),
                                            padding: const EdgeInsets.all(4),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (context) =>
                                                  _FullScreenVideoDialog(
                                                track: _cameraTrack!,
                                                title:
                                                    '${widget.studentName} - CAM 01',
                                                fit: VideoViewFit.cover,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    Positioned(
                                      top: 12,
                                      left: 12,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color:
                                              Colors.red.withValues(alpha: 0.8),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: const Row(
                                          children: [
                                            Icon(Icons.fiber_manual_record,
                                                color: Colors.white, size: 10),
                                            SizedBox(width: 4),
                                            Text('REC',
                                                style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 9,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 12,
                                      right: 12,
                                      child: Text(
                                        DateTime.now()
                                            .toIso8601String()
                                            .substring(11, 19),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontFamily: 'Courier'),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text('SCR 02 - EXAM TERMINAL',
                              style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Container(
                            height: 120,
                            decoration: BoxDecoration(
                              color: const Color(0xFF020617),
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: const Color(0xFF1E293B)),
                            ),
                            child: Center(
                              child: isOnline
                                  ? (_screenTrack != null
                                      ? Stack(
                                          children: [
                                            Center(
                                              child: VideoTrackRenderer(
                                                _screenTrack!,
                                                fit: VideoViewFit.contain,
                                              ),
                                            ),
                                            Positioned(
                                              top: 8,
                                              right: 8,
                                              child: IconButton(
                                                icon: const Icon(
                                                    Icons.fullscreen_rounded,
                                                    color: Colors.white,
                                                    size: 20),
                                                style: IconButton.styleFrom(
                                                  backgroundColor: Colors.black
                                                      .withValues(alpha: 0.6),
                                                  padding:
                                                      const EdgeInsets.all(4),
                                                  minimumSize: Size.zero,
                                                  tapTargetSize:
                                                      MaterialTapTargetSize
                                                          .shrinkWrap,
                                                ),
                                                onPressed: () {
                                                  showDialog(
                                                    context: context,
                                                    builder: (context) =>
                                                        _FullScreenVideoDialog(
                                                      track: _screenTrack!,
                                                      title:
                                                          '${widget.studentName} - SCR 02',
                                                      fit: VideoViewFit.contain,
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ],
                                        )
                                      : const Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.screenshot,
                                                size: 36, color: Colors.blue),
                                            SizedBox(height: 8),
                                            Text(
                                              'ACTIVE EXAM PAGE OPEN',
                                              style: TextStyle(
                                                color: Colors.blue,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ))
                                  : const Text('SCREEN DISCONNECTED',
                                      style: TextStyle(
                                          color: Colors.grey, fontSize: 10)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 300,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('REAL-TIME PROCTOR LOGS',
                              style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Container(
                            height: 160,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF020617),
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: const Color(0xFF1E293B)),
                            ),
                            child: Builder(builder: (context) {
                              final rawLogs = session['proctor_logs'];
                              List<dynamic> logList = [];
                              if (rawLogs is List) {
                                logList = rawLogs;
                              }
                              if (logList.isEmpty) {
                                return const Center(
                                  child: Text('No logs available.',
                                      style: TextStyle(
                                          color: Colors.grey, fontSize: 10)),
                                );
                              }
                              return ListView.builder(
                                itemCount: logList.length,
                                itemBuilder: (context, index) {
                                  final logItem = logList[index];
                                  if (logItem is! Map) {
                                    return const SizedBox.shrink();
                                  }
                                  final timeStr =
                                      logItem['time']?.toString() ?? '';
                                  final eventStr =
                                      logItem['event']?.toString() ?? '';
                                  final severity =
                                      logItem['severity']?.toString() ?? 'info';
                                  return _buildLogLine(
                                    timeStr,
                                    eventStr,
                                    isWarning: severity == 'warning',
                                    isInfo: severity == 'info',
                                    isError: severity == 'error',
                                  );
                                },
                              );
                            }),
                          ),
                          const SizedBox(height: 16),
                          const Text('AUDIO MONITORING (MIC)',
                              style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF020617),
                              borderRadius: BorderRadius.circular(16),
                              border:
                                  Border.all(color: const Color(0xFF1E293B)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.mic,
                                    color: Colors.green, size: 18),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Container(
                                    height: 30,
                                    alignment: Alignment.centerLeft,
                                    child:
                                        _MicEqualizerMeter(isOnline: isOnline),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  isOnline ? '32 dB' : '0 dB',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text('CONSOLE CONTROLS',
                              style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          if (status == 'completed' ||
                              status == 'suspended') ...[
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () async {
                                  await widget.onReopen(
                                      widget.sessionId, widget.studentName);
                                  setState(() {});
                                },
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981)),
                                child: const Text('Reopen Exam Session',
                                    style: TextStyle(
                                        fontSize: 11, color: Colors.white)),
                              ),
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      await widget.onWarn(
                                          widget.sessionId, widget.studentName);
                                      setState(() {});
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange.shade800,
                                    ),
                                    child: const Text('Warn',
                                        style: TextStyle(
                                            fontSize: 11, color: Colors.white)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      await widget.onPause(widget.sessionId,
                                          widget.studentName, !isPaused);
                                      setState(() {});
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          isPaused ? Colors.green : Colors.red,
                                    ),
                                    child: Text(isPaused ? 'Resume' : 'Pause',
                                        style: const TextStyle(
                                            fontSize: 11, color: Colors.white)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      final camActive =
                                          session['camera_active'] as bool? ??
                                              true;
                                      await widget.onToggleCamera(
                                          widget.sessionId,
                                          widget.studentName,
                                          camActive);
                                      setState(() {});
                                    },
                                    icon: Icon(
                                      (session['camera_active'] as bool? ??
                                              true)
                                          ? Icons.videocam
                                          : Icons.videocam_off,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                    label: Text(
                                      (session['camera_active'] as bool? ??
                                              true)
                                          ? 'Cam: ON'
                                          : 'Cam: OFF',
                                      style: const TextStyle(
                                          fontSize: 11, color: Colors.white),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          (session['camera_active'] as bool? ??
                                                  true)
                                              ? Colors.green.shade800
                                              : Colors.red.shade900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      final micActive =
                                          session['mic_active'] as bool? ??
                                              true;
                                      await widget.onToggleMic(widget.sessionId,
                                          widget.studentName, micActive);
                                      setState(() {});
                                    },
                                    icon: Icon(
                                      (session['mic_active'] as bool? ?? true)
                                          ? Icons.mic
                                          : Icons.mic_off,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                    label: Text(
                                      (session['mic_active'] as bool? ?? true)
                                          ? 'Mic: ON'
                                          : 'Mic: OFF',
                                      style: const TextStyle(
                                          fontSize: 11, color: Colors.white),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          (session['mic_active'] as bool? ??
                                                  true)
                                              ? Colors.green.shade800
                                              : Colors.red.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      _showFeedCustomTimeExtensionDialog();
                                    },
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF334155)),
                                    child: const Text('Extend Time',
                                        style: TextStyle(
                                            fontSize: 11, color: Colors.white)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      await widget.onSuspend(
                                          widget.sessionId, widget.studentName);
                                      if (context.mounted) {
                                        Navigator.pop(context);
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red.shade900),
                                    child: const Text('Suspend',
                                        style: TextStyle(
                                            fontSize: 11, color: Colors.white)),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullScreenVideoDialog extends StatelessWidget {
  final VideoTrack track;
  final String title;
  final VideoViewFit fit;

  const _FullScreenVideoDialog({
    required this.track,
    required this.title,
    this.fit = VideoViewFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: const Color(0xFF020617),
      child: Stack(
        children: [
          Center(
            child: VideoTrackRenderer(
              track,
              fit: fit,
            ),
          ),
          Positioned(
            top: 20,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Positioned(
            top: 20,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 28),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
                padding: const EdgeInsets.all(8),
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }
}
