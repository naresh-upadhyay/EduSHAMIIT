import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:edu_shamiit_ai/core/utils/l10n.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/services/teacher_api_service.dart';
import 'package:edu_shamiit_ai/core/models/teacher_models.dart';

class TeacherLiveClasses extends ConsumerStatefulWidget {
  const TeacherLiveClasses({super.key});

  @override
  ConsumerState<TeacherLiveClasses> createState() => _TeacherLiveClassesState();
}

class _TeacherLiveClassesState extends ConsumerState<TeacherLiveClasses> {
  final TeacherApiService _apiService = TeacherApiService();
  
  String _selectedStatus = 'All';
  final List<String> _statuses = ['All', 'Scheduled', 'Ongoing', 'Completed'];
  List<TeacherLiveClass> _liveClasses = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLiveClasses();
  }

  Future<void> _loadLiveClasses() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final status = _selectedStatus == 'All' ? null : _selectedStatus.toLowerCase();
      final liveClasses = await _apiService.getLiveClasses(status: status);
      setState(() {
        _liveClasses = liveClasses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Color _getStatusColor(String status) {
    final s = status.toLowerCase();
    if (s == 'ongoing' || s == 'live') {
      return Colors.green;
    } else if (s == 'scheduled') {
      return Colors.blue;
    } else {
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(16, Responsive.headerTopPadding(context), 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFEF4444), Color(0xFFF87171)],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => safeGoBack(context, '/teacher/dashboard'),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Live Classes',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.video_call, color: Colors.white),
                  onPressed: () => _showScheduleDialog(),
                ),
              ],
            ),
          ),

          // Status filter
          SizedBox(
            height: 56,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _statuses.length,
              itemBuilder: (context, index) {
                final status = _statuses[index];
                final isSelected = _selectedStatus == status;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedStatus = status);
                    _loadLiveClasses();
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFEF4444) : const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : const Color(0xFFEF4444),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Loading state
          if (_isLoading)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            ),

          // Error state
          if (_error != null)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text('Error: $_error', style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadLiveClasses,
                      child: Text('Retry'.tr(ref)),
                    ),
                  ],
                ),
              ),
            ),

          // Live classes list
          if (!_isLoading && _error == null)
            Expanded(
              child: _liveClasses.isEmpty
                  ? Center(child: Text('No live classes found'.tr(ref)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _liveClasses.length,
                      itemBuilder: (context, index) {
                        return _buildLiveClassCard(_liveClasses[index]);
                      },
                    ),
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showScheduleDialog(),
        backgroundColor: const Color(0xFFEF4444),
        icon: const Icon(Icons.video_call, color: Colors.white),
        label: const Text(
          'Schedule',
          style: TextStyle(
            fontFamily: AppFonts.heading,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildLiveClassCard(TeacherLiveClass liveClass) {
    final statusColor = _getStatusColor(liveClass.status);
    final statusLower = liveClass.status.toLowerCase();
    final isLive = statusLower == 'ongoing' || statusLower == 'live';
    final isScheduled = statusLower == 'scheduled';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isLive ? statusColor.withValues(alpha: 0.5) : const Color(0xFFE2E8F0),
        ),
        boxShadow: isLive
            ? [BoxShadow(color: statusColor.withValues(alpha: 0.2), blurRadius: 12)]
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  liveClass.title,
                  style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              if (isLive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'LIVE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                liveClass.scheduledAt.toString().split('.')[0],
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.class_, size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                'Class ${liveClass.class_}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            liveClass.subject,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          if (isLive)
            ElevatedButton.icon(
              onPressed: () => _joinBroadcasting(liveClass),
              icon: const Icon(Icons.video_call, color: Colors.white),
              label: Text('Open Studio'.tr(ref), style: const TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            )
          else if (isScheduled)
            ElevatedButton.icon(
              onPressed: () => _startBroadcasting(liveClass),
              icon: const Icon(Icons.play_arrow, color: Colors.white),
              label: Text('Start Broadcasting'.tr(ref), style: const TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _startBroadcasting(TeacherLiveClass liveClass) async {
    try {
      await _apiService.patchLiveClass(liveClass.id, {
        "status": "live",
      });
      _loadLiveClasses();
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => _TeacherLiveBroadcastingScreen(liveClass: liveClass),
          ),
        ).then((_) => _loadLiveClasses());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error starting class: $e')),
        );
      }
    }
  }

  void _joinBroadcasting(TeacherLiveClass liveClass) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _TeacherLiveBroadcastingScreen(liveClass: liveClass),
      ),
    ).then((_) => _loadLiveClasses());
  }

  void _showScheduleDialog() {
    final titleController = TextEditingController();
    final linkController = TextEditingController(text: 'https://www.youtube.com/embed/dQw4w9WgXcQ?autoplay=1&mute=1&modestbranding=1&rel=0');
    final durationController = TextEditingController(text: '60');
    
    String selectedClass = 'X-A';
    String selectedSubject = 'Physics';
    DateTime selectedDateTime = DateTime.now().add(const Duration(hours: 1));
    bool isUploadRecording = false;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  const Icon(Icons.video_call, color: Color(0xFFEF4444), size: 28),
                  const SizedBox(width: 8),
                  Text(
                    isUploadRecording ? 'Upload Recording' : 'Schedule Live Class',
                    style: const TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tab Switcher
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setDialogState(() => isUploadRecording = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: !isUploadRecording ? const Color(0xFFEF4444) : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: !isUploadRecording ? Colors.transparent : Colors.white10),
                              ),
                              child: Center(
                                child: Text(
                                  'Live Class',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: !isUploadRecording ? Colors.white : Colors.white60,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setDialogState(() => isUploadRecording = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isUploadRecording ? const Color(0xFFEF4444) : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: isUploadRecording ? Colors.transparent : Colors.white10),
                              ),
                              child: Center(
                                child: Text(
                                  'Recording',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isUploadRecording ? Colors.white : Colors.white60,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Title Field
                    const Text('Class Title', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: titleController,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: isUploadRecording ? 'e.g. Physics — Wave Optics' : 'e.g. Physics — Optics Chapter 9',
                        hintStyle: const TextStyle(color: Colors.white30),
                        filled: true,
                        fillColor: const Color(0xFF0F172A),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Target Class & Subject Row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Target Class', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: selectedClass,
                                dropdownColor: const Color(0xFF1E293B),
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFF0F172A),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                items: ['X-A', 'X-B', 'IX-A']
                                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                    .toList(),
                                onChanged: (val) => setDialogState(() => selectedClass = val ?? 'X-A'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Subject', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                value: selectedSubject,
                                dropdownColor: const Color(0xFF1E293B),
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFF0F172A),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                                items: ['Physics', 'Mathematics', 'Chemistry', 'English']
                                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                                    .toList(),
                                onChanged: (val) => setDialogState(() => selectedSubject = val ?? 'Physics'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Date & Time Picker (if scheduling upcoming)
                    if (!isUploadRecording) ...[
                      const Text('Scheduled Time', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: selectedDateTime,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 30)),
                          );
                          if (date != null) {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.fromDateTime(selectedDateTime),
                            );
                            if (time != null) {
                              setDialogState(() {
                                selectedDateTime = DateTime(
                                  date.year,
                                  date.month,
                                  date.day,
                                  time.hour,
                                  time.minute,
                                );
                              });
                            }
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, color: Colors.white54, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                selectedDateTime.toString().split('.')[0],
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Duration and Stream/Recording Link
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Duration (min)', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              TextField(
                                controller: durationController,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFF0F172A),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isUploadRecording ? 'Recording Embed URL' : 'Meeting / Stream URL',
                                style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: linkController,
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFF0F172A),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final title = titleController.text.trim();
                          final link = linkController.text.trim();
                          final duration = int.tryParse(durationController.text.trim()) ?? 60;

                          if (title.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('⚠️ Title is required')),
                            );
                            return;
                          }
                          if (link.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('⚠️ URL link is required')),
                            );
                            return;
                          }

                          setDialogState(() => isSubmitting = true);

                          try {
                            await _apiService.createLiveClass(
                              title: title,
                              classId: selectedClass,
                              subject: selectedSubject,
                              scheduledAt: isUploadRecording ? DateTime.now() : selectedDateTime,
                              durationMinutes: duration,
                              status: isUploadRecording ? 'recorded' : 'scheduled',
                              streamUrl: isUploadRecording ? null : link,
                              recordingUrl: isUploadRecording ? link : null,
                            );

                            Navigator.pop(context);
                            _loadLiveClasses();

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                backgroundColor: const Color(0xFF10B981),
                                content: Row(
                                  children: [
                                    const Icon(Icons.check_circle, color: Colors.white),
                                    const SizedBox(width: 8),
                                    Text(
                                      isUploadRecording
                                          ? 'Recorded class uploaded successfully!'
                                          : 'Live class scheduled successfully!',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          } catch (e) {
                            setDialogState(() => isSubmitting = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('❌ Error: $e')),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: isSubmitting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(isUploadRecording ? 'Upload' : 'Schedule', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _TeacherLiveBroadcastingScreen extends StatefulWidget {
  final TeacherLiveClass liveClass;

  const _TeacherLiveBroadcastingScreen({required this.liveClass});

  @override
  State<_TeacherLiveBroadcastingScreen> createState() => _TeacherLiveBroadcastingScreenState();
}

class _TeacherLiveBroadcastingScreenState extends State<_TeacherLiveBroadcastingScreen> {
  final TeacherApiService _apiService = TeacherApiService();
  List<Map<String, dynamic>> _comments = [];
  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isSharing = false;
  bool _isEnding = false;
  int _viewers = 35;
  
  final TextEditingController _replyController = TextEditingController();
  Map<String, dynamic>? _pinnedComment;
  Timer? _commentsTimer;

  @override
  void initState() {
    super.initState();
    _loadComments();
    _commentsTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _loadComments();
    });
  }

  @override
  void dispose() {
    _commentsTimer?.cancel();
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    try {
      final comments = await _apiService.getComments(widget.liveClass.id);
      if (mounted) {
        setState(() {
          _comments = comments;
          final pinned = comments.firstWhere((c) => c['pinned'] == true, orElse: () => {});
          if (pinned.isNotEmpty) {
            _pinnedComment = pinned;
          } else {
            _pinnedComment = null;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _postTeacherReply({bool pin = false}) async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    try {
      final res = await _apiService.postComment(widget.liveClass.id, text, isPinned: pin);
      if (res != null) {
        _replyController.clear();
        _loadComments();
      }
    } catch (_) {}
  }

  Future<void> _endLiveClass() async {
    setState(() => _isEnding = true);
    try {
      await _apiService.patchLiveClass(widget.liveClass.id, {
        "status": "recorded",
        "recording_url": widget.liveClass.meetingLink ?? "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
      });
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF10B981),
            content: Text('✅ Session ended. Recording saved successfully.'),
          ),
        );
      }
    } catch (e) {
      setState(() => _isEnding = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error ending session: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        child: Column(
          children: [
            // Top Header Row
            Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFF1E293B),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.liveClass.title,
                          style: const TextStyle(
                            fontFamily: AppFonts.heading,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${widget.liveClass.subject} · ${widget.liveClass.class_}',
                          style: const TextStyle(fontSize: 11, color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // LIVE badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'LIVE',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Viewers
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '👥 $_viewers',
                      style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),

            // Video/Camera Viewport area
            Expanded(
              flex: 4,
              child: Stack(
                children: [
                  Container(
                    color: Colors.black,
                    width: double.infinity,
                    child: Center(
                      child: _isVideoOff
                          ? const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.videocam_off, size: 64, color: Colors.white38),
                                SizedBox(height: 8),
                                Text(
                                  'Camera is Off',
                                  style: TextStyle(color: Colors.white38, fontSize: 13),
                                ),
                              ],
                            )
                          : Stack(
                              alignment: Alignment.center,
                              children: [
                                // Mock Camera background / screen share preview
                                Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Color(0xFF0C4A6E), Color(0xFF0369A1)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                ),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      '👩‍🏫',
                                      style: TextStyle(fontSize: 80),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _isSharing ? 'Screen Share Active' : 'Broadcasting Live Video',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'EduSHAMIIT Broadcasting Studio',
                                      style: TextStyle(color: Colors.white38, fontSize: 11),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                    ),
                  ),

                  // Overlay for Screen Share Active
                  if (_isSharing)
                    Positioned.fill(
                      child: Container(
                        color: Colors.indigo.withOpacity(0.9),
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.screen_share, size: 64, color: Colors.white),
                              SizedBox(height: 12),
                              Text(
                                'You are sharing your screen',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Students see your active presentations',
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                  // Pinned Comment Banner in player!
                  if (_pinnedComment != null)
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withOpacity(0.9),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6)],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('📌', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_pinnedComment!['user']} (${_pinnedComment!['role'].toString().toUpperCase()})',
                                    style: const TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _pinnedComment!['text'] ?? '',
                                    style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
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

            // Live Chat Area
            Expanded(
              flex: 3,
              child: Container(
                color: const Color(0xFF1E293B),
                child: Column(
                  children: [
                    // Chat header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.white10)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.chat_bubble_outline, size: 14, color: Colors.white70),
                          const SizedBox(width: 6),
                          const Text(
                            'Live Comments Feed',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white70),
                          ),
                          const Spacer(),
                          Text(
                            '${_comments.length} comments',
                            style: const TextStyle(fontSize: 10, color: Colors.white38),
                          ),
                        ],
                      ),
                    ),

                    // Comments List
                    Expanded(
                      child: _comments.isEmpty
                          ? const Center(
                              child: Text(
                                'No comments yet. Students will appear here.',
                                style: TextStyle(color: Colors.white38, fontSize: 11),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: _comments.length,
                              itemBuilder: (context, index) {
                                final comment = _comments[index];
                                final isTeacher = comment['role'] == 'teacher';
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF334155),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            comment['user'] != null && comment['user'].isNotEmpty ? comment['user'][0] : '👤',
                                            style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Text(
                                                  comment['user'] ?? 'User',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: isTeacher ? const Color(0xFF34D399) : const Color(0xFFA78BFA),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                const Text(
                                                  'Just now',
                                                  style: TextStyle(fontSize: 8, color: Colors.white38),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              comment['text'] ?? '',
                                              style: const TextStyle(fontSize: 11, color: Colors.white70),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),

                    // Input Field & Announcement Post option
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFF0F172A),
                        border: Border(top: BorderSide(color: Colors.white10)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _replyController,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              decoration: InputDecoration(
                                hintText: 'Post announcement / reply...',
                                hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                                filled: true,
                                fillColor: const Color(0xFF1E293B),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Post Announcement Button (Pins the message instantly)
                          IconButton(
                            icon: const Icon(Icons.push_pin, color: Color(0xFF818CF8), size: 20),
                            tooltip: 'Pin Announcement',
                            onPressed: () => _postTeacherReply(pin: true),
                          ),
                          // Regular send button
                          IconButton(
                            icon: const Icon(Icons.send, color: Color(0xFF10B981), size: 20),
                            onPressed: () => _postTeacherReply(pin: false),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom studio control bar
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              color: Colors.black,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Mute Mic
                  _buildStudioControlBtn(
                    icon: _isMuted ? Icons.mic_off : Icons.mic,
                    color: _isMuted ? Colors.red : Colors.white24,
                    onTap: () => setState(() => _isMuted = !_isMuted),
                  ),
                  // Video camera toggle
                  _buildStudioControlBtn(
                    icon: _isVideoOff ? Icons.videocam_off : Icons.videocam,
                    color: _isVideoOff ? Colors.red : Colors.white24,
                    onTap: () => setState(() => _isVideoOff = !_isVideoOff),
                  ),
                  // Screen Share
                  _buildStudioControlBtn(
                    icon: Icons.screen_share,
                    color: _isSharing ? const Color(0xFF4F46E5) : Colors.white24,
                    onTap: () => setState(() => _isSharing = !_isSharing),
                  ),
                  // End Class Button (saves recording)
                  ElevatedButton(
                    onPressed: _isEnding ? null : _endLiveClass,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isEnding
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text(
                            'End Session',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudioControlBtn({required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}
