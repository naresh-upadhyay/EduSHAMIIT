import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:ui_web' as ui_web;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/providers/live_classes_provider.dart';

class StudentLiveClasses extends ConsumerStatefulWidget {
  const StudentLiveClasses({super.key});

  @override
  ConsumerState<StudentLiveClasses> createState() => _StudentLiveClassesState();
}

class _StudentLiveClassesState extends ConsumerState<StudentLiveClasses> {
  bool _hasCheckedAutoPlay = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_hasCheckedAutoPlay) {
      try {
        final uri = GoRouterState.of(context).uri;
        final playSubject = uri.queryParameters['playSubject'];
        if (playSubject != null) {
          final liveClassesState = ref.read(liveClassesProvider);
          if (!liveClassesState.isLoading && liveClassesState.recorded.isNotEmpty) {
            _hasCheckedAutoPlay = true;
            final match = liveClassesState.recorded.firstWhere(
              (c) => c.subject.toLowerCase().contains(playSubject.toLowerCase()),
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

    if (!_hasCheckedAutoPlay && !liveClassesState.isLoading && liveClassesState.recorded.isNotEmpty) {
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
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
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
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '🔴 ${liveClassesState.liveNow.length} Live Now',
                    style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: liveClassesState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : liveClassesState.error != null
                    ? Center(child: Text('Error: ${liveClassesState.error}'))
                    : ListView(
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
                          ...liveClassesState.liveNow.map((cls) => _buildLiveCard(cls)),
                          
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
                              child: Text('No upcoming classes today', style: TextStyle(fontSize: 11, color: StudentColors.text3)),
                            ),
                          ...liveClassesState.upcoming.map((cls) => _buildUpcomingCard(cls)),
                          
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
                              child: Text('No recorded classes', style: TextStyle(fontSize: 11, color: StudentColors.text3)),
                            ),
                          ...liveClassesState.recorded.map((cls) => _buildRecordedCard(cls)),
                          
                          const SizedBox(height: 50),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveCard(LiveClassModel cls) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: StudentColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCA5A5), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        children: [
          // Video thumbnail area
          Container(
            height: 110,
            decoration: BoxDecoration(
              gradient: cls.color ?? const LinearGradient(colors: [Color(0xFF1E293B), Color(0xFF334155)]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Stack(
              children: [
                Center(child: Text(cls.icon, style: const TextStyle(fontSize: 40))),
                // LIVE badge
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: StudentColors.error,
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
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
                // Viewers count
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '👥 ${cls.viewers ?? 0} watching',
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ),
                // Teacher avatar
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF334155),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: StudentColors.primary, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        cls.teacher.isNotEmpty ? cls.teacher[0] : '👨‍🏫',
                        style: const TextStyle(fontSize: 20, color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Info
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cls.subject,
                  style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${cls.teacher}  ${cls.started ?? ''}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: StudentColors.text3,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _joinClass(cls),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: StudentColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('▶ Join Now', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: StudentColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: StudentColors.border),
                      ),
                      child: const Icon(Icons.notifications_none, size: 18, color: StudentColors.text2),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingCard(LiveClassModel cls) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: StudentColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: StudentColors.successBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(cls.icon, style: const TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cls.subject,
                  style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${cls.teacher}  ${cls.time ?? ''}',
                  style: const TextStyle(
                    fontSize: 10,
                    color: StudentColors.text3,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: StudentColors.warningBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              cls.timeUntil ?? '',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: StudentColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordedCard(LiveClassModel cls) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: StudentColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: StudentColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: StudentColors.border),
            ),
            child: const Center(child: Text('📹', style: TextStyle(fontSize: 18))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cls.subject,
                  style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  cls.date ?? '',
                  style: const TextStyle(
                    fontSize: 10,
                    color: StudentColors.text3,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _playRecording(cls),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF64748B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('▶ Play', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _joinClass(LiveClassModel cls) {
    ref.read(liveClassesProvider.notifier).joinClass(cls.id);
    context.go('/student/live-classes/play/${cls.id}');
  }

  void _playRecording(LiveClassModel cls) {
    context.go('/student/live-classes/play/${cls.id}');
  }
}

// Live Class Detail Screen (YouTube-style)
class StudentLiveClassPlayerScreen extends ConsumerStatefulWidget {
  final String classId;

  const StudentLiveClassPlayerScreen({super.key, required this.classId});

  @override
  ConsumerState<StudentLiveClassPlayerScreen> createState() => _StudentLiveClassPlayerScreenState();
}

class _StudentLiveClassPlayerScreenState extends ConsumerState<StudentLiveClassPlayerScreen> {
  static final Set<String> _registeredIds = {};
  
  List<Map<String, dynamic>> _comments = [];
  bool _isLoadingComments = true;
  bool _isLiked = false;
  bool _isDisliked = false;
  bool _isSubscribed = false;
  bool _isShareSelected = false;
  bool _isSaveSelected = false;
  bool _isNotesSelected = false;

  int _likeCount = 342;
  int _dislikeCount = 12;

  final TextEditingController _commentController = TextEditingController();

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
    }
    return url;
  }

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    final comments = await ref.read(liveClassesProvider.notifier).fetchComments(widget.classId);
    if (mounted) {
      setState(() {
        _comments = comments;
        _isLoadingComments = false;
      });
    }
  }

  Future<void> _postComment(String text) async {
    if (text.trim().isEmpty) return;
    final newComment = await ref.read(liveClassesProvider.notifier).postComment(widget.classId, text.trim());
    if (newComment != null && mounted) {
      setState(() {
        // Insert new comment at index 1 to keep pinned comments at the top if any
        int insertIndex = _comments.indexWhere((c) => c['pinned'] == true) + 1;
        if (insertIndex <= 0) insertIndex = 0;
        _comments.insert(insertIndex, newComment);
        _commentController.clear();
      });
    }
  }

  void _registerIframe(LiveClassModel classData) {
    if (_registeredIds.contains(classData.id)) return;
    _registeredIds.add(classData.id);
    
    var rawUrl = classData.type == 'live' 
        ? classData.streamUrl 
        : classData.recordingUrl;
    rawUrl ??= 'https://www.youtube.com/embed/dQw4w9WgXcQ?autoplay=1&mute=1&modestbranding=1&rel=0';
    
    final videoUrl = _getEmbedUrl(rawUrl);
    
    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(
      'youtube-iframe-${classData.id}',
      (int viewId) => html.IFrameElement()
        ..width = '100%'
        ..height = '100%'
        ..src = videoUrl
        ..style.border = 'none'
        ..allow = 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture'
        ..attributes['allowfullscreen'] = 'true',
    );
  }

  @override
  Widget build(BuildContext context) {
    final liveClassesState = ref.watch(liveClassesProvider);

    if (liveClassesState.isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0F172A),
        body: Center(
          child: CircularProgressIndicator(color: Colors.red),
        ),
      );
    }

    final classList = [...liveClassesState.liveNow, ...liveClassesState.upcoming, ...liveClassesState.recorded];
    final LiveClassModel? classData = classList.any((c) => c.id == widget.classId)
        ? classList.firstWhere((c) => c.id == widget.classId)
        : null;

    if (classData == null) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_off, size: 48, color: Colors.white54),
              const SizedBox(height: 16),
              const Text('Class recording not found', style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/student/live-classes'),
                child: const Text('Back to Live Classes'),
              ),
            ],
          ),
        ),
      );
    }

    if (kIsWeb) {
      _registerIframe(classData);
    }

    final isLive = classData.isLive || classData.type == 'live';

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Column(
        children: [
          // Video Player Area (Premium Full-Width Theater/Cinematic backdrop)
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.55,
            ),
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                color: Colors.black,
                child: Stack(
                  children: [
                  // Full-bleed Video elements (cinematic theater styling)
                  Positioned.fill(
                    child: kIsWeb
                        ? HtmlElementView(
                            key: ValueKey('youtube-iframe-view-${classData.id}'),
                            viewType: 'youtube-iframe-${classData.id}',
                          )
                        : Container(
                            color: Colors.black,
                            child: Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    classData.icon,
                                    style: const TextStyle(fontSize: 60),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    isLive ? '🔴 Live Class in Progress' : '📹 Recorded Class Playback',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: AppFonts.heading,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'EduSHAMIIT Premium Player',
                                    style: TextStyle(color: Colors.white30, fontSize: 10),
                                  ),
                                  const SizedBox(height: 16),
                                  // Large glowing Play Button
                                  Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: isLive ? Colors.red : Colors.white24,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: isLive ? Colors.red.withOpacity(0.5) : Colors.black26,
                                          blurRadius: 12,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.play_arrow,
                                      color: Colors.white,
                                      size: 32,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                  
                  // Status Badge (LIVE / RECORDED)
                  Positioned(
                    top: 16,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isLive ? Colors.red.withOpacity(0.9) : const Color(0xFF64748B).withOpacity(0.9),
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
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Text(
                              'LIVE',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                          ] else ...[
                            const Icon(Icons.videocam, size: 10, color: Colors.white),
                            const SizedBox(width: 4),
                            const Text(
                              'RECORDED',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                          ]
                        ],
                      ),
                    ),
                  ),

                  // Viewers/Views count
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isLive 
                            ? '👁️ ${classData.viewers ?? 34} watching'
                            : '👁️ ${classData.viewers ?? 856} views',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ),
                  ),

                  // Back button
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () {
                          context.go('/student/live-classes');
                        },
                      ),
                    ),
                  ),

                  // Live Teacher Picture-in-Picture
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: Container(
                      width: 56,
                      height: 72,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: StudentColors.primary, width: 2),
                      ),
                      child: Center(
                        child: Text(
                          classData.teacher.isNotEmpty ? classData.teacher[0] : '👨‍🏫',
                          style: const TextStyle(fontSize: 24, color: Colors.white),
                        ),
                      ),
                    ),
                  ),

                  // Scrub / Seek Progress Bar stretching the entire width of the player!
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 4,
                      color: Colors.white24,
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: isLive ? 0.35 : 0.72,
                        child: Container(color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
         ),

          // Scrollable Body containing Info Block, Divider, Comments Header, and Comments list (removes nested layout constraints)
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: 3 + (_isLoadingComments ? 1 : (_comments.isEmpty ? 1 : _comments.length)),
              itemBuilder: (context, index) {
                if (index == 0) {
                  // Video Info Block (YouTube style)
                  return Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          classData.subject,
                          style: const TextStyle(
                            fontFamily: AppFonts.heading,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isLive 
                              ? '${classData.viewers ?? 34} watching  ·  ${classData.started ?? 'Started 25 min ago'}'
                              : '${classData.viewers ?? 856} views  ·  ${classData.date ?? 'Mar 25'}',
                          style: const TextStyle(fontSize: 10, color: Colors.white54),
                        ),
                        const SizedBox(height: 12),

                        // Channel/Teacher Row
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)],
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  classData.teacher.isNotEmpty ? classData.teacher[0] : '👨‍🏫',
                                  style: const TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    classData.teacher,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const Text(
                                    'Academic Faculty Dept.',
                                    style: TextStyle(fontSize: 9, color: Colors.white38),
                                  ),
                                ],
                              ),
                            ),
                            // Subscribe Button (Mockup action)
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _isSubscribed = !_isSubscribed;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _isSubscribed ? const Color(0xFF334155) : Colors.red,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: Text(
                                _isSubscribed ? 'Subscribed ✓' : 'Subscribe',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Interactive Action Buttons
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              // Like
                              GestureDetector(
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
                                child: _buildActionChip('👍 $_likeCount', isSelected: _isLiked),
                              ),
                              // Dislike
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _isDisliked = !_isDisliked;
                                    if (_isDisliked) {
                                      _isLiked = false;
                                    }
                                  });
                                },
                                child: _buildActionChip('👎 $_dislikeCount', isSelected: _isDisliked),
                              ),
                              // Share
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _isShareSelected = !_isShareSelected;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('🔗 Stream share link copied to clipboard!')),
                                  );
                                },
                                child: _buildActionChip('📤 Share', isSelected: _isShareSelected),
                              ),
                              // Save
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _isSaveSelected = !_isSaveSelected;
                                  });
                                },
                                child: _buildActionChip('📥 Save', isSelected: _isSaveSelected),
                              ),
                              // Notes
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _isNotesSelected = !_isNotesSelected;
                                  });
                                },
                                child: _buildActionChip('📝 Notes', isSelected: _isNotesSelected),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                } else if (index == 1) {
                  return const Divider(color: Colors.white10, height: 1);
                } else if (index == 2) {
                  // Comments Section Header
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        const Text(
                          '💬 Comments',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            fontFamily: AppFonts.heading,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_comments.length}',
                          style: const TextStyle(fontSize: 12, color: Colors.white38, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        const Text(
                          'Sort by ▾',
                          style: TextStyle(fontSize: 10, color: Color(0xFF38BDF8), fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  );
                } else {
                  // Comments content
                  if (_isLoadingComments) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: CircularProgressIndicator(color: StudentColors.primary),
                      ),
                    );
                  }
                  if (_comments.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 30),
                        child: Text('No comments yet.', style: TextStyle(color: Colors.white30, fontSize: 11)),
                      ),
                    );
                  }

                  final commentIndex = index - 3;
                  final comment = _comments[commentIndex];
                  final isPinned = comment['pinned'] == true;

                  if (isPinned) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12, left: 14, right: 14),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withOpacity(0.15),
                        border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.3)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '📌 PINNED BY TEACHER',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF818CF8), letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 6),
                          _buildCommentRow(comment),
                        ],
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: _buildCommentRow(comment),
                  );
                }
              },
            ),
          ),

          // Comment Input Area
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              border: Border(top: BorderSide(color: Colors.white10)),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [Color(0xFF4F46E5), Color(0xFF06B6D4)]),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('🧑', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: InputDecoration(
                      hintText: 'Add a public comment...',
                      hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                      filled: true,
                      fillColor: const Color(0xFF0F172A),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    ),
                    onSubmitted: (value) => _postComment(value),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _postComment(_commentController.text),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Color(0xFF38BDF8),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send, size: 14, color: Color(0xFF0F172A)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionChip(String label, {bool isSelected = false}) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isSelected ? Colors.transparent : Colors.white10),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }

  Widget _buildCommentRow(Map<String, dynamic> comment) {
    final likes = comment['likes'] ?? 0;
    final userName = comment['user'] ?? 'User';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFF334155),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white10),
            ),
            child: Center(
              child: Text(
                userName.isNotEmpty ? userName[0] : '👤',
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
                      userName,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: comment['role'] == 'teacher' ? const Color(0xFF34D399) : const Color(0xFFA78BFA),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      comment['time'] ?? 'Just now',
                      style: const TextStyle(fontSize: 9, color: Colors.white38),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  comment['text'] ?? '',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text('👍 $likes', style: const TextStyle(fontSize: 9, color: Colors.white38)),
                    const SizedBox(width: 10),
                    const Text('Reply', style: TextStyle(fontSize: 9, color: Colors.white38)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
}
