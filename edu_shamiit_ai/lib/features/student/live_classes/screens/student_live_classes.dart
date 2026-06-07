import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:ui_web' as ui_web;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/providers/live_classes_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:edu_shamiit_ai/core/providers/auth_provider.dart';
import 'package:edu_shamiit_ai/core/providers/role_provider.dart';
import 'package:edu_shamiit_ai/core/providers/api_provider.dart';

class StudentLiveClasses extends ConsumerStatefulWidget {
  const StudentLiveClasses({super.key});

  @override
  ConsumerState<StudentLiveClasses> createState() => _StudentLiveClassesState();
}

class _StudentLiveClassesState extends ConsumerState<StudentLiveClasses> {
  bool _hasCheckedAutoPlay = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(liveClassesProvider.notifier).loadLiveClasses();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasCheckedAutoPlay) {
      try {
        final uri = GoRouterState.of(context).uri;
        final playSubject = uri.queryParameters['playSubject'];
        if (playSubject != null) {
          final liveClassesState = ref.read(liveClassesProvider);
          if (!liveClassesState.isLoading &&
              liveClassesState.recorded.isNotEmpty) {
            _hasCheckedAutoPlay = true;
            final match = liveClassesState.recorded.firstWhere(
              (c) =>
                  c.subject.toLowerCase().contains(playSubject.toLowerCase()),
              orElse: () => liveClassesState.recorded.first,
            );
            WidgetsBinding.instance.addPostFrameCallback((_) {
              context.go('/student/live-classes/play/${match.id}');
            });
          }
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final liveClassesState = ref.watch(liveClassesProvider);

    if (!_hasCheckedAutoPlay &&
        !liveClassesState.isLoading &&
        liveClassesState.recorded.isNotEmpty) {
      try {
        final uri = GoRouterState.of(context).uri;
        final playSubject = uri.queryParameters['playSubject'];
        if (playSubject != null) {
          _hasCheckedAutoPlay = true;
          final match = liveClassesState.recorded.firstWhere(
            (c) => c.subject.toLowerCase().contains(playSubject.toLowerCase()),
            orElse: () => liveClassesState.recorded.first,
          );
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.go('/student/live-classes/play/${match.id}');
          });
        }
      } catch (_) {}
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(
                16, Responsive.headerTopPadding(context), 16, 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => safeGoBack(context, '/student/dashboard'),
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
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  tooltip: 'Refresh classes',
                  onPressed: () =>
                      ref.read(liveClassesProvider.notifier).loadLiveClasses(),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '🔴 ${liveClassesState.liveNow.length} Live Now',
                    style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(liveClassesProvider.notifier).loadLiveClasses(),
              color: StudentColors.primary,
              child: liveClassesState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : liveClassesState.error != null
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            SizedBox(
                              height: MediaQuery.of(context).size.height * 0.6,
                              child: Center(
                                  child:
                                      Text('Error: ${liveClassesState.error}')),
                            ),
                          ],
                        )
                      : ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16),
                          children: [
                            // Live Now Section
                            const Text(
                              '🔴 LIVE NOW',
                              style: TextStyle(
                                fontFamily: AppFonts.heading,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: StudentColors.error,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ...liveClassesState.liveNow
                                .map((cls) => _buildLiveCard(cls)),

                            const SizedBox(height: 20),

                            // Upcoming Section
                            const Text(
                              '📅 UPCOMING TODAY',
                              style: TextStyle(
                                fontFamily: AppFonts.heading,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: StudentColors.text3,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (liveClassesState.upcoming.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text('No upcoming classes today',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: StudentColors.text3)),
                              ),
                            ...liveClassesState.upcoming
                                .map((cls) => _buildUpcomingCard(cls)),

                            const SizedBox(height: 20),

                            // Recorded Section
                            const Text(
                              '📋 RECORDED CLASSES',
                              style: TextStyle(
                                fontFamily: AppFonts.heading,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: StudentColors.text3,
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (liveClassesState.recorded.isEmpty)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                child: Text('No recorded classes',
                                    style: TextStyle(
                                        fontSize: 11,
                                        color: StudentColors.text3)),
                              ),
                            ...liveClassesState.recorded
                                .map((cls) => _buildRecordedCard(cls)),

                            const SizedBox(height: 50),
                          ],
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveCard(LiveClassModel cls) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFECACA), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFEF4444).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            // Header Image area
            Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: cls.color ??
                    const LinearGradient(
                      colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Center(
                      child: Text(
                        cls.icon.isNotEmpty ? cls.icon : '📚',
                        style: const TextStyle(fontSize: 44),
                      ),
                    ),
                  ),
                  // LIVE badge
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color:
                                const Color(0xFFEF4444).withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
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
                          const SizedBox(width: 6),
                          const Text(
                            'LIVE',
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Watching badge
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '👥 ${cls.viewers ?? 0} watching',
                        style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Colors.white),
                      ),
                    ),
                  ),
                  // Teacher avatar overlay
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          cls.teacher.isNotEmpty ? cls.teacher[0] : '👨‍🏫',
                          style: const TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Details area
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          cls.subject,
                          style: const TextStyle(
                            fontFamily: AppFonts.heading,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildPlatformBadge(cls.platform),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.person_outline_rounded,
                          size: 12, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(
                        cls.teacher,
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.sensors_rounded,
                          size: 12, color: Color(0xFFEF4444)),
                      const SizedBox(width: 4),
                      Text(
                        cls.started ?? 'Just started',
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFFEF4444),
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _joinClass(cls),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            shadowColor:
                                const Color(0xFFEF4444).withValues(alpha: 0.3),
                            elevation: 4,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.play_arrow_rounded,
                                  color: Colors.white, size: 16),
                              SizedBox(width: 6),
                              Text('Join Room',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpcomingCard(LiveClassModel cls) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                cls.icon.isNotEmpty ? cls.icon : '📅',
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        cls.subject,
                        style: const TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildPlatformBadge(cls.platform),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      cls.teacher,
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 8),
                    const Text('·', style: TextStyle(color: Color(0xFF94A3B8))),
                    const SizedBox(width: 8),
                    Text(
                      cls.time ?? '',
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              cls.timeUntil ?? '',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2563EB),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordedCard(LiveClassModel cls) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF8FAFC), Color(0xFFF1F5F9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: Icon(Icons.play_circle_fill_rounded,
                  color: Color(0xFF64748B), size: 24),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        cls.subject,
                        style: const TextStyle(
                          fontFamily: AppFonts.heading,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildPlatformBadge(cls.platform),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      cls.teacher,
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(width: 8),
                    const Text('·', style: TextStyle(color: Color(0xFF94A3B8))),
                    const SizedBox(width: 8),
                    Text(
                      cls.date ?? '',
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: () => _playRecording(cls),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF334155),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Play',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _launchMeeting(String urlString) async {
    final url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open link: $urlString')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open link: $e')),
      );
    }
  }

  Widget _buildPlatformBadge(String platform) {
    Color bg = const Color(0xFFF1F5F9);
    Color fg = const Color(0xFF334155);
    IconData icon = Icons.video_call;

    final lower = platform.toLowerCase();
    if (lower == 'zoom') {
      bg = const Color(0xFFE0F2FE);
      fg = const Color(0xFF0369A1);
      icon = Icons.videocam;
    } else if (lower.contains('meet') || lower.contains('google')) {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF15803D);
      icon = Icons.groups;
    } else if (lower == 'youtube') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFB91C1C);
      icon = Icons.play_circle_fill;
    } else if (lower == 'in-app' || lower == 'edushamiit') {
      bg = const Color(0xFFEEF2FF);
      fg = const Color(0xFF4338CA);
      icon = Icons.bolt;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: fg),
          const SizedBox(width: 4),
          Text(
            platform,
            style:
                TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: fg),
          ),
        ],
      ),
    );
  }

  void _joinClass(LiveClassModel cls) {
    ref.read(liveClassesProvider.notifier).joinClass(cls.id);
    if (cls.platform.toLowerCase() == 'in-app' ||
        cls.platform.toLowerCase() == 'edushamiit') {
      final auth = ref.read(authProvider);
      context.push(
        '/live-room',
        extra: {
          'liveClassId': cls.id,
          'currentUserId': auth.userData?['id'] ?? '',
          'currentUserName': auth.userData?['full_name'] ?? 'Student',
          'currentUserRole': 'student',
          'title': cls.subject,
        },
      ).then((_) {
        ref.read(liveClassesProvider.notifier).loadLiveClasses();
      });
    } else {
      final link = cls.meetingLink ?? cls.streamUrl;
      if (link != null && link.isNotEmpty) {
        _launchMeeting(link);
      } else {
        context.go('/student/live-classes/play/${cls.id}');
      }
    }
  }

  void _playRecording(LiveClassModel cls) {
    context.go('/student/live-classes/play/${cls.id}');
  }
}

class StudentLiveClassPlayerScreen extends ConsumerStatefulWidget {
  final String classId;

  const StudentLiveClassPlayerScreen({super.key, required this.classId});

  @override
  ConsumerState<StudentLiveClassPlayerScreen> createState() =>
      _StudentLiveClassPlayerScreenState();
}

class _StudentLiveClassPlayerScreenState
    extends ConsumerState<StudentLiveClassPlayerScreen> {
  static final Set<String> _registeredViewKeys = {};
  String _viewInstanceKey = '';

  List<Map<String, dynamic>> _comments = [];
  bool _isLoadingComments = true;
  bool _isLiked = false;
  bool _isDisliked = false;
  bool _isSubscribed = false;
  bool _isSaved = false;

  int _likeCount = 342;
  int _userRating = 0;
  bool _hasRated = false;
  bool _showAudioWarning = true;
  bool _showIntroOverlay = true;

  final TextEditingController _commentController = TextEditingController();
  String? _replyingToCommentId;
  final TextEditingController _replyController = TextEditingController();

  final TextEditingController _notesController = TextEditingController();
  bool _notesSaved = false;

  LiveClassModel? _localClassData;
  bool _isLoadingClassData = true;

  String _activeTab =
      'Overview'; // 'Overview', 'Chapters', 'Resources', 'Notes'

  final List<Map<String, dynamic>> _chapters = [
    {'time': '00:00', 'seconds': 0, 'title': 'Introduction & Class Overview'},
    {'time': '02:15', 'seconds': 135, 'title': 'Core Concepts & Background'},
    {
      'time': '08:40',
      'seconds': 520,
      'title': 'Practical Walkthrough & Calculations'
    },
    {'time': '12:10', 'seconds': 730, 'title': 'Student Live Q&A Session'},
    {
      'time': '17:45',
      'seconds': 1065,
      'title': 'Summary & Homework Assignment'
    },
  ];

  final List<Map<String, String>> _resources = [
    {'title': 'Lecture Notes Handout.pdf', 'size': '2.4 MB', 'type': 'pdf'},
    {'title': 'Practice Exercise Sheet.pdf', 'size': '1.1 MB', 'type': 'pdf'},
    {'title': 'Formulas Reference Card.pdf', 'size': '850 KB', 'type': 'pdf'},
  ];

  @override
  void initState() {
    super.initState();
    _viewInstanceKey =
        '${widget.classId}-${DateTime.now().millisecondsSinceEpoch}';
    _loadClassDataAndComments();
  }

  @override
  void didUpdateWidget(StudentLiveClassPlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.classId != widget.classId) {
      _viewInstanceKey =
          '${widget.classId}-${DateTime.now().millisecondsSinceEpoch}';
      _loadClassDataAndComments();
    }
  }

  void _startIntroOverlayTimer() {
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showIntroOverlay = false;
        });
      }
    });
  }

  Future<void> _loadClassDataAndComments() async {
    if (!mounted) return;
    setState(() {
      _isLoadingClassData = true;
      _isLoadingComments = true;
      _showAudioWarning = true;
      _notesSaved = false;
      _notesController.clear();
      _showIntroOverlay = true;
    });

    _loadComments();

    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.get('/live-classes/${widget.classId}');
      if (response['success'] == true && response['data'] != null) {
        if (mounted) {
          setState(() {
            _localClassData = LiveClassModel.fromJson(response['data']);
            _isLoadingClassData = false;
            _showIntroOverlay = true;
          });
          _startIntroOverlayTimer();
          return;
        }
      }
    } catch (e) {
      debugPrint(
          '[PlayerScreen] Failed to fetch from single class endpoint: $e');
    }

    // Fallback: check provider list
    final liveClassesState = ref.read(liveClassesProvider);
    final classList = [
      ...liveClassesState.liveNow,
      ...liveClassesState.upcoming,
      ...liveClassesState.recorded
    ];
    final match = classList.any((c) => c.id == widget.classId)
        ? classList.firstWhere((c) => c.id == widget.classId)
        : null;

    if (mounted) {
      setState(() {
        _localClassData = match;
        _isLoadingClassData = false;
        _showIntroOverlay = true;
      });
      _startIntroOverlayTimer();
    }
  }

  /// Fix internal host name mapping for container media assets URL to browser-accessible address
  String _fixStorageUrl(String url) {
    if (url.contains('kong:8000')) {
      return url.replaceAll('kong:8000', '127.0.0.1:8000');
    }
    return url;
  }

  String _getEmbedUrl(String url) {
    if (url.contains('watch?v=')) {
      final parts = url.split('watch?v=');
      if (parts.length > 1) {
        final videoId = parts[1].split('&')[0];
        return 'https://www.youtube.com/embed/$videoId?autoplay=1&mute=1&modestbranding=1&rel=0';
      }
    } else if (url.contains('youtu.be/')) {
      final parts = url.split('youtu.be/');
      if (parts.length > 1) {
        final videoId = parts[1].split('?')[0];
        return 'https://www.youtube.com/embed/$videoId?autoplay=1&mute=1&modestbranding=1&rel=0';
      }
    } else if (url.contains('youtube.com/embed/')) {
      if (!url.contains('autoplay=')) {
        final sep = url.contains('?') ? '&' : '?';
        return '$url${sep}autoplay=1&mute=1';
      }
    }
    return url;
  }

  Future<void> _loadComments() async {
    final comments = await ref
        .read(liveClassesProvider.notifier)
        .fetchComments(widget.classId);
    if (mounted) {
      setState(() {
        _comments = comments;
        _isLoadingComments = false;
      });
    }
  }

  Future<void> _postComment(String text) async {
    if (text.trim().isEmpty) return;
    final newComment = await ref
        .read(liveClassesProvider.notifier)
        .postComment(widget.classId, text.trim());
    if (newComment != null && mounted) {
      setState(() {
        int insertIndex = _comments.indexWhere((c) => c['pinned'] == true) + 1;
        if (insertIndex <= 0) insertIndex = 0;
        _comments.insert(insertIndex, newComment);
        _commentController.clear();
      });
    }
  }

  Future<void> _postReply(String commentId) async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;
    final newReply = await ref.read(liveClassesProvider.notifier).postComment(
          widget.classId,
          text,
          parentId: commentId,
        );
    if (newReply != null && mounted) {
      setState(() {
        final parentIdx =
            _comments.indexWhere((c) => c['id'].toString() == commentId);
        if (parentIdx != -1) {
          final List<dynamic> repliesList =
              _comments[parentIdx]['replies'] != null
                  ? List.from(_comments[parentIdx]['replies'] as Iterable)
                  : [];
          repliesList.add(newReply);
          _comments[parentIdx]['replies'] = repliesList;
        }
        _replyingToCommentId = null;
        _replyController.clear();
      });
    }
  }

  void _registerIframe(LiveClassModel classData, String viewKey) {
    if (_registeredViewKeys.contains(viewKey)) return;
    _registeredViewKeys.add(viewKey);

    final String resolvedUrl = _fixStorageUrl(
      (classData.type == 'live'
              ? classData.streamUrl
              : classData.recordingUrl) ??
          '',
    );

    final isDirectVideo = resolvedUrl.endsWith('.mp4') ||
        resolvedUrl.endsWith('.webm') ||
        resolvedUrl.endsWith('.ogg') ||
        resolvedUrl.contains('/storage/v1/object/public/') ||
        resolvedUrl.contains(':9000/live-classes/');

    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(
      viewKey,
      (int viewId) {
        if (resolvedUrl.isEmpty) {
          final div = html.DivElement()
            ..style.display = 'flex'
            ..style.flexDirection = 'column'
            ..style.alignItems = 'center'
            ..style.justifyContent = 'center'
            ..style.width = '100%'
            ..style.height = '100%'
            ..style.background = '#0F172A'
            ..style.color = 'rgba(255,255,255,0.6)'
            ..style.fontSize = '16px'
            ..style.fontFamily = 'sans-serif';

          final textSpan = html.SpanElement()
            ..text = '🎥 Recording not generated yet';
          div.append(textSpan);
          return div;
        } else if (isDirectVideo) {
          final video = html.VideoElement()
            ..id = 'live-class-video-player'
            ..width = 1280
            ..height = 720
            ..src = resolvedUrl
            ..controls = true
            ..autoplay = true
            ..muted = true
            ..style.border = 'none'
            ..style.width = '100%'
            ..style.height = '100%'
            ..style.background = '#000';
          video.setAttribute('playsinline', '');
          video.setAttribute('webkit-playsinline', '');
          return video;
        } else {
          final videoUrl = _getEmbedUrl(resolvedUrl);
          return html.IFrameElement()
            ..width = '100%'
            ..height = '100%'
            ..src = videoUrl
            ..style.border = 'none'
            ..allow =
                'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; fullscreen'
            ..attributes['allowfullscreen'] = 'true';
        }
      },
    );
  }

  void _seekVideo(int seconds) {
    if (kIsWeb) {
      try {
        final video = html.document.getElementById('live-class-video-player')
            as html.VideoElement?;
        if (video != null) {
          video.currentTime = seconds;
          video.play();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  '⚡ Seeked to ${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, "0")}'),
              duration: const Duration(seconds: 1),
              backgroundColor: const Color(0xFFEF4444),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Browser player controls unavailable.')),
          );
        }
      } catch (e) {
        debugPrint('Error seeking: $e');
      }
    }
  }

  void _unmuteVideo() {
    if (kIsWeb) {
      try {
        final video = html.document.getElementById('live-class-video-player')
            as html.VideoElement?;
        if (video != null) {
          video.muted = false;
          setState(() {
            _showAudioWarning = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('🔊 Audio unmuted!'),
                duration: Duration(seconds: 1)),
          );
        }
      } catch (e) {
        debugPrint('Error unmuting: $e');
      }
    }
  }

  void _shareStream() {
    final String path = html.window.location.href;
    Clipboard.setData(ClipboardData(text: path));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔗 Playback share link copied to clipboard!'),
        backgroundColor: Color(0xFF10B981),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingClassData) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFEF4444)),
        ),
      );
    }

    final classData = _localClassData;
    final isTeacher = ref.read(authProvider).role == UserRole.teacher;

    if (classData == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_off_rounded,
                  size: 64, color: Colors.white38),
              const SizedBox(height: 16),
              const Text('Class recording not found',
                  style: TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go(isTeacher
                    ? '/teacher/live-classes'
                    : '/student/live-classes'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444)),
                child: const Text('Back to Live Classes',
                    style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      );
    }

    if (kIsWeb) {
      _registerIframe(classData, _viewInstanceKey);
    }

    final isLive = classData.isLive || classData.type == 'live';
    final isDesktop = MediaQuery.of(context).size.width > 950;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      body: isDesktop
          ? _buildDesktopLayout(classData, isLive, isTeacher)
          : _buildMobileLayout(classData, isLive, isTeacher),
    );
  }

  // ---------------------------------------------------------------------------
  // DESKTOP LAYOUT (SPLIT 2-COLUMN VIEW)
  // ---------------------------------------------------------------------------
  Widget _buildDesktopLayout(
      LiveClassModel classData, bool isLive, bool isTeacher) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column (70% width): Player, Title, Tabs
        Expanded(
          flex: 7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Player container
              _buildPlayerArea(classData, isLive, isTeacher),

              // Autoplay Unmute Alert Banner
              if (_showAudioWarning && kIsWeb) _buildMuteWarningBanner(),

              // Information Panel (Title, Description, Tabs)
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTitleBlock(classData),
                      const SizedBox(height: 16),
                      _buildTabBar(),
                      const SizedBox(height: 16),
                      _buildTabContent(classData),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Right Column (30% width): Channels, Related Classes, Comments
        Expanded(
          flex: 3,
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              border: Border(left: BorderSide(color: Colors.white12, width: 1)),
            ),
            child: Column(
              children: [
                _buildQuickActionsPanel(classData),
                const Divider(color: Colors.white10, height: 1),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSidebarLecturesList(),
                        const Divider(color: Colors.white10, height: 20),
                        _buildCommentsAreaSection(),
                      ],
                    ),
                  ),
                ),
                _buildCommentInputBar(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // MOBILE LAYOUT (VERTICAL STACK VIEW)
  // ---------------------------------------------------------------------------
  Widget _buildMobileLayout(
      LiveClassModel classData, bool isLive, bool isTeacher) {
    return Column(
      children: [
        // Top Player
        _buildPlayerArea(classData, isLive, isTeacher),

        // Autoplay Unmute Alert Banner
        if (_showAudioWarning && kIsWeb) _buildMuteWarningBanner(),

        // Scrollable Details & Sidebar
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTitleBlock(classData),
                      const SizedBox(height: 12),
                      _buildQuickActionsPanel(classData),
                      const SizedBox(height: 16),
                      _buildTabBar(),
                      const SizedBox(height: 16),
                      _buildTabContent(classData),
                    ],
                  ),
                ),
                const Divider(color: Colors.white10, height: 20),
                _buildSidebarLecturesList(),
                const Divider(color: Colors.white10, height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildCommentsAreaSection(),
                ),
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),

        // Mobile Sticky Comment Input
        _buildCommentInputBar(),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // SUB-WIDGET BUILDERS
  // ---------------------------------------------------------------------------
  Widget _buildPlayerArea(
      LiveClassModel classData, bool isLive, bool isTeacher) {
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            // Video Platform View / Embed
            Positioned.fill(
              child: kIsWeb
                  ? HtmlElementView(
                      key: ValueKey(_viewInstanceKey),
                      viewType: _viewInstanceKey,
                    )
                  : Container(
                      color: const Color(0xFF0F172A),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                                classData.icon.isNotEmpty
                                    ? classData.icon
                                    : '📹',
                                style: const TextStyle(fontSize: 60)),
                            const SizedBox(height: 12),
                            Text(
                              isLive
                                  ? '🔴 Live Session in Progress'
                                  : '📹 Class Recording Playback',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),

            // Back navigation circle
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                decoration: const BoxDecoration(
                    color: Colors.black54, shape: BoxShape.circle),
                child: IconButton(
                  icon:
                      const Icon(Icons.arrow_back_rounded, color: Colors.white),
                  onPressed: () {
                    context.go(isTeacher
                        ? '/teacher/live-classes'
                        : '/student/live-classes');
                  },
                ),
              ),
            ),

            // Live status badge
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isLive
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF64748B),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLive) ...[
                      Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                              color: Colors.white, shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      isLive ? 'LIVE' : 'RECORDED',
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),

            // Viewer/Views overlay
            Positioned(
              bottom: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6)),
                child: Text(
                  isLive
                      ? '👁️ ${classData.viewers ?? 34} watching'
                      : '👁️ ${classData.viewers ?? 856} views',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70),
                ),
              ),
            ),

            // Intro overlay card
            if (_showIntroOverlay)
              IgnorePointer(
                child: Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.85),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444)
                                  .withValues(alpha: 0.2),
                              border: Border.all(
                                  color: const Color(0xFFEF4444), width: 1.5),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              (classData.subjectName ?? '').isNotEmpty
                                  ? classData.subjectName!.toUpperCase()
                                  : 'LECTURE',
                              style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: Text(
                              classData.title ?? '',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Presented by ${classData.teacher}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.videocam_rounded,
                                  color: Colors.white38, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                'Recorded Lecture Playback',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  fontSize: 10,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMuteWarningBanner() {
    return Container(
      width: double.infinity,
      color: const Color(0xFF7C2D12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          const Icon(Icons.volume_off_rounded,
              color: Color(0xFFFDBA74), size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Audio is muted due to browser autoplay limits. Click Unmute to enable sound.',
              style: TextStyle(
                  color: Color(0xFFFED7AA),
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: _unmuteVideo,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEA580C),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              textStyle:
                  const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
            child: const Text('Unmute'),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleBlock(LiveClassModel classData) {
    // Show title or subject
    final String displayTitle =
        (classData.title != null && classData.title!.isNotEmpty)
            ? classData.title!
            : classData.subject;
    final String displaySub = classData.subjectName ?? classData.subject;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                displayTitle,
                style: const TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                    colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                displaySub,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Colors.white),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          classData.date ?? 'Class session details',
          style: const TextStyle(fontSize: 11, color: Colors.white38),
        ),
      ],
    );
  }

  Widget _buildQuickActionsPanel(LiveClassModel classData) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Teacher Bio Card
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)]),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    classData.teacher.isNotEmpty
                        ? classData.teacher[0]
                        : '👨‍🏫',
                    style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      classData.teacher,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    const Text(
                      'Senior Academic Faculty',
                      style: TextStyle(fontSize: 9, color: Colors.white38),
                    ),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isSubscribed = !_isSubscribed;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_isSubscribed
                          ? '🔔 Notifications enabled for ${classData.teacher}'
                          : '🔕 Notifications disabled'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isSubscribed
                      ? const Color(0xFF334155)
                      : const Color(0xFFEF4444),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  _isSubscribed ? 'Subscribed' : 'Subscribe',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Action buttons: Like, Share, Save, Rate Class
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Like / Dislike Split
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      InkWell(
                        onTap: () {
                          setState(() {
                            _isLiked = !_isLiked;
                            if (_isLiked) {
                              _likeCount++;
                              _isDisliked = false;
                            } else {
                              _likeCount--;
                            }
                          });
                        },
                        borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(24),
                            bottomLeft: Radius.circular(24)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          child: Row(
                            children: [
                              Icon(
                                _isLiked
                                    ? Icons.thumb_up_rounded
                                    : Icons.thumb_up_outlined,
                                color: _isLiked
                                    ? const Color(0xFF38BDF8)
                                    : Colors.white70,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text('$_likeCount',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      Container(width: 1, height: 16, color: Colors.white24),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _isDisliked = !_isDisliked;
                            if (_isDisliked) {
                              _isLiked = false;
                            }
                          });
                        },
                        borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(24),
                            bottomRight: Radius.circular(24)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          child: Icon(
                            _isDisliked
                                ? Icons.thumb_down_rounded
                                : Icons.thumb_down_outlined,
                            color: _isDisliked
                                ? const Color(0xFFEF4444)
                                : Colors.white70,
                            size: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Share
                InkWell(
                  onTap: _shareStream,
                  borderRadius: BorderRadius.circular(24),
                  child: _buildActionBadge(Icons.share_rounded, 'Share'),
                ),
                const SizedBox(width: 8),

                // Save
                InkWell(
                  onTap: () {
                    setState(() {
                      _isSaved = !_isSaved;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(_isSaved
                              ? '📁 Saved to library!'
                              : '📁 Removed from library')),
                    );
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: _buildActionBadge(
                    _isSaved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    'Save',
                    isSelected: _isSaved,
                  ),
                ),
              ],
            ),
          ),

          // Rating Dialog Section
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rate this lecture session:',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(5, (index) {
                    final int starValue = index + 1;
                    return IconButton(
                      icon: Icon(
                        _userRating >= starValue
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: _userRating >= starValue
                            ? const Color(0xFFF59E0B)
                            : Colors.white24,
                      ),
                      iconSize: 24,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: _hasRated
                          ? null
                          : () {
                              setState(() {
                                _userRating = starValue;
                                _hasRated = true;
                              });
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      '⭐ Thank you for rating this lecture $starValue stars!'),
                                  backgroundColor: const Color(0xFFF59E0B),
                                ),
                              );
                            },
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBadge(IconData icon, String label,
      {bool isSelected = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? const Color(0xFF38BDF8).withValues(alpha: 0.15)
            : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: isSelected
                ? const Color(0xFF38BDF8).withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              color: isSelected ? const Color(0xFF38BDF8) : Colors.white70,
              size: 14),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? const Color(0xFF38BDF8) : Colors.white)),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final List<String> tabs = ['Overview', 'Chapters', 'Resources', 'My Notes'];
    return Container(
      height: 40,
      decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.white10, width: 1))),
      child: Row(
        children: tabs.map((tab) {
          final isSelected = _activeTab == tab;
          return Padding(
            padding: const EdgeInsets.only(right: 20),
            child: InkWell(
              onTap: () {
                setState(() {
                  _activeTab = tab;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  border: isSelected
                      ? const Border(
                          bottom:
                              BorderSide(color: Color(0xFFEF4444), width: 2.5))
                      : null,
                ),
                child: Text(
                  tab,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : Colors.white38,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTabContent(LiveClassModel classData) {
    switch (_activeTab) {
      case 'Chapters':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Lecture Timeline Chapters',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ..._chapters.map((ch) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8)),
                child: ListTile(
                  dense: true,
                  leading: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4)),
                    child: Text(
                      ch['time'],
                      style: const TextStyle(
                          color: Color(0xFFEF4444),
                          fontWeight: FontWeight.bold,
                          fontSize: 10),
                    ),
                  ),
                  title: Text(ch['title'],
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.87),
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.play_circle_fill_rounded,
                      color: Colors.white30, size: 18),
                  onTap: () => _seekVideo(ch['seconds']),
                ),
              );
            }),
          ],
        );
      case 'Resources':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Downloadable Lecture Materials',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ..._resources.map((res) {
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8)),
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.picture_as_pdf_rounded,
                      color: Color(0xFFEF4444), size: 20),
                  title: Text(res['title']!,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.87),
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                  subtitle: Text(res['size']!,
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 9)),
                  trailing: const Icon(Icons.download_rounded,
                      color: Color(0xFF38BDF8), size: 18),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('📥 Downloading ${res['title']}...'),
                          backgroundColor: const Color(0xFF38BDF8)),
                    );
                  },
                ),
              );
            }),
          ],
        );
      case 'Notes':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Take session notes:',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: _notesController,
              maxLines: 6,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                hintText:
                    'Type your lecture summary, key formulas or remarks here...',
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
                fillColor: const Color(0xFF1E293B),
                filled: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _notesSaved ? '✓ Saved locally' : 'Unsaved changes',
                  style: TextStyle(
                      color: _notesSaved
                          ? const Color(0xFF10B981)
                          : Colors.white24,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _notesSaved = true;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              '✓ Notes successfully saved for this lecture.'),
                          backgroundColor: Color(0xFF10B981)),
                    );
                  },
                  icon: const Icon(Icons.save_rounded, size: 14),
                  label:
                      const Text('Save Notes', style: TextStyle(fontSize: 10)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                ),
              ],
            ),
          ],
        );
      case 'Overview':
      default:
        final String displayDesc = (classData.description != null &&
                classData.description!.isNotEmpty)
            ? classData.description!
            : 'Welcome to this recorded lecture session. In this session, we investigate deep curriculum concepts, go through live practice files, and check step-by-step calculations. Review resources and seek direct chapters to skip ahead.';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Description',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              displayDesc,
              style: const TextStyle(
                  color: Colors.white60, fontSize: 11.5, height: 1.5),
            ),
            const SizedBox(height: 16),
            const Text('Session Details',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildDetailRow('Platform / Server:', classData.platform),
            _buildDetailRow('Stream Type:', classData.type.toUpperCase()),
            _buildDetailRow('Duration mapped:',
                '${classData.timeUntil ?? "Recorded Class"} (${classData.date ?? ""})'),
          ],
        );
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(label,
              style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 11,
                  fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Text(value,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.87), fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildSidebarLecturesList() {
    final recordedList = ref.read(liveClassesProvider).recorded;
    final otherRecordings =
        recordedList.where((c) => c.id != widget.classId).toList();

    if (otherRecordings.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('📚 Related Lecture Playbacks',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: otherRecordings.length,
            itemBuilder: (context, index) {
              final rec = otherRecordings[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.02)),
                ),
                child: ListTile(
                  dense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8)),
                    child: Center(
                      child: Text(rec.icon.isNotEmpty ? rec.icon : '📚',
                          style: const TextStyle(fontSize: 18)),
                    ),
                  ),
                  title: Text(
                    (rec.title != null && rec.title!.isNotEmpty)
                        ? rec.title!
                        : rec.subject,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${rec.teacher} · ${rec.date ?? "Recorded"}',
                    style: const TextStyle(color: Colors.white38, fontSize: 9),
                  ),
                  onTap: () {
                    // Update URL and reload the video page
                    final isTeacher =
                        ref.read(authProvider).role == UserRole.teacher;
                    final String routePath = isTeacher
                        ? '/teacher/live-classes/play/${rec.id}'
                        : '/student/live-classes/play/${rec.id}';
                    context.go(routePath);
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsAreaSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('💬 Session Comments',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(8)),
                child: Text('${_comments.length}',
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 9,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isLoadingComments)
            const Center(
                child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(color: Color(0xFFEF4444))))
          else if (_comments.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No comments yet. Write a remark below!',
                    style: TextStyle(color: Colors.white24, fontSize: 11)),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _comments.length,
              itemBuilder: (context, idx) {
                final comment = _comments[idx];
                return _buildCommentRow(comment);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildCommentRow(Map<String, dynamic> comment,
      {bool isReply = false}) {
    final userName = comment['user'] ?? 'User';
    final commentId = comment['id'].toString();
    final likes = comment['likes'] ?? 0;

    return Padding(
      padding: EdgeInsets.only(bottom: 12, left: isReply ? 24 : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Color(0xFF334155), Color(0xFF475569)]),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    userName.isNotEmpty ? userName[0] : '👤',
                    style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.bold),
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
                        Text(userName,
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white70)),
                        if (comment['role'] == 'teacher') ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                                color: const Color(0xFF064E3B),
                                borderRadius: BorderRadius.circular(4)),
                            child: const Text('FACULTY',
                                style: TextStyle(
                                    fontSize: 7,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF34D399))),
                          ),
                        ],
                        const SizedBox(width: 8),
                        Text(comment['time'] ?? 'Just now',
                            style: const TextStyle(
                                fontSize: 8, color: Colors.white24)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      comment['text'] ?? '',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 10.5,
                          height: 1.35),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.thumb_up_alt_outlined,
                            size: 10, color: Colors.white30),
                        const SizedBox(width: 4),
                        Text('$likes',
                            style: const TextStyle(
                                fontSize: 8, color: Colors.white38)),
                        if (!isReply) ...[
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                if (_replyingToCommentId == commentId) {
                                  _replyingToCommentId = null;
                                } else {
                                  _replyingToCommentId = commentId;
                                }
                              });
                            },
                            child: const Text('Reply',
                                style: TextStyle(
                                    fontSize: 8.5,
                                    color: Color(0xFF38BDF8),
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Nested replies input
          if (_replyingToCommentId == commentId)
            Padding(
              padding: const EdgeInsets.only(left: 34, top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _replyController,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 10.5),
                      decoration: InputDecoration(
                        hintText: 'Write a reply...',
                        hintStyle: const TextStyle(
                            color: Colors.white24, fontSize: 10.5),
                        fillColor: const Color(0xFF1E293B),
                        filled: true,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none),
                      ),
                      onSubmitted: (_) => _postReply(commentId),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send_rounded,
                        size: 14, color: Color(0xFF38BDF8)),
                    onPressed: () => _postReply(commentId),
                  ),
                ],
              ),
            ),

          // Thread replies loop
          if (!isReply &&
              comment['replies'] != null &&
              (comment['replies'] as List).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                children: (comment['replies'] as List)
                    .map((reply) => _buildCommentRow(
                        Map<String, dynamic>.from(reply),
                        isReply: true))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCommentInputBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: Color(0xFF0B0F19),
        border: Border(top: BorderSide(color: Colors.white10, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              style: const TextStyle(color: Colors.white, fontSize: 11.5),
              decoration: InputDecoration(
                hintText: 'Add a public comment...',
                hintStyle:
                    const TextStyle(color: Colors.white24, fontSize: 11.5),
                fillColor: const Color(0xFF1E293B),
                filled: true,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide.none),
              ),
              onSubmitted: _postComment,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.send_rounded,
                size: 18, color: Color(0xFF38BDF8)),
            onPressed: () => _postComment(_commentController.text),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    _replyController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
