import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:edu_shamiit_ai/core/utils/live_class_player_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/shared/widgets/nav_helper.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/providers/live_classes_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:edu_shamiit_ai/core/providers/auth_provider.dart';
import 'package:edu_shamiit_ai/core/providers/role_provider.dart';
import 'package:edu_shamiit_ai/core/providers/api_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:edu_shamiit_ai/core/config/app_config.dart';
import 'package:file_picker/file_picker.dart';
import 'package:edu_shamiit_ai/shared/widgets/azure_grid.dart';

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

    final List<LiveClassModel> allClasses = [
      ...liveClassesState.liveNow,
      ...liveClassesState.upcoming,
      ...liveClassesState.recorded,
    ];

    final columns = [
      AzureGridColumn<LiveClassModel>(
        label: 'Subject',
        width: 160.0,
        compare: (a, b) => a.subject.compareTo(b.subject),
        cellBuilder: (cls) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(cls.icon.isNotEmpty ? cls.icon : '📚', style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 8),
            Text(cls.subject, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      AzureGridColumn<LiveClassModel>(
        label: 'Title',
        width: 200.0,
        compare: (a, b) => (a.title ?? '').compareTo(b.title ?? ''),
        cellBuilder: (cls) => Text(cls.title ?? 'Class Session', overflow: TextOverflow.ellipsis),
      ),
      AzureGridColumn<LiveClassModel>(
        label: 'Teacher',
        width: 140.0,
        compare: (a, b) => a.teacher.compareTo(b.teacher),
        cellBuilder: (cls) => Text(cls.teacher),
      ),
      AzureGridColumn<LiveClassModel>(
        label: 'Schedule / Date',
        width: 160.0,
        compare: (a, b) => (a.time ?? a.date ?? '').compareTo(b.time ?? b.date ?? ''),
        cellBuilder: (cls) => Text(cls.time ?? cls.date ?? 'N/A'),
      ),
      AzureGridColumn<LiveClassModel>(
        label: 'Type',
        width: 120.0,
        compare: (a, b) => a.type.compareTo(b.type),
        cellBuilder: (cls) {
          final isLive = cls.type == 'live';
          final isUpcoming = cls.type == 'upcoming';
          final bg = isLive
              ? const Color(0xFFFEE2E2)
              : isUpcoming
                  ? const Color(0xFFEFF6FF)
                  : const Color(0xFFF1F5F9);
          final fg = isLive
              ? const Color(0xFFEF4444)
              : isUpcoming
                  ? const Color(0xFF3B82F6)
                  : const Color(0xFF64748B);
          final label = isLive
              ? '🔴 Live'
              : isUpcoming
                  ? '📅 Upcoming'
                  : '📋 Recorded';
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              label,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: fg),
            ),
          );
        },
      ),
      AzureGridColumn<LiveClassModel>(
        label: 'Platform',
        width: 120.0,
        compare: (a, b) => a.platform.compareTo(b.platform),
        cellBuilder: (cls) => _buildPlatformBadge(cls.platform),
      ),
      AzureGridColumn<LiveClassModel>(
        label: 'Action',
        width: 140.0,
        cellBuilder: (cls) {
          if (cls.type == 'live') {
            return SizedBox(
              height: 26,
              child: ElevatedButton(
                onPressed: () => _joinClass(cls),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                child: const Text('Join Room', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            );
          } else if (cls.type == 'recorded') {
            return SizedBox(
              height: 26,
              child: ElevatedButton(
                onPressed: () => _playRecording(cls),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF334155),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                ),
                child: const Text('Play', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            );
          } else {
            return Text(cls.timeUntil ?? 'Scheduled', style: const TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic));
          }
        },
      ),
    ];

    final filters = [
      AzureGridFilter<LiveClassModel>(
        label: 'Type',
        options: const ['Live', 'Upcoming', 'Recorded'],
        filterFn: (cls, option) => cls.type.toLowerCase() == option.toLowerCase(),
      ),
      AzureGridFilter<LiveClassModel>(
        label: 'Subject',
        options: allClasses.map((e) => e.subject).toSet().toList(),
        filterFn: (cls, option) => cls.subject == option,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        child: Column(
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

            liveClassesState.isLoading
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : liveClassesState.error != null
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40.0),
                        child: Center(child: Text('Error: ${liveClassesState.error}')),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(16),
                        child: AzureGrid<LiveClassModel>(
                          title: 'Live & Recorded Sessions',
                          items: allClasses,
                          columns: columns,
                          filters: filters,
                          onRefresh: () => ref.read(liveClassesProvider.notifier).loadLiveClasses(),
                          searchMatcher: (cls) => '${cls.subject} ${cls.teacher} ${cls.title ?? ""}',
                          mobileCardBuilder: (context, cls) {
                            if (cls.type == 'live') return _buildLiveCard(cls);
                            if (cls.type == 'upcoming') return _buildUpcomingCard(cls);
                            return _buildRecordedCard(cls);
                          },
                          disableVerticalScroll: true,
                        ),
                      ),
          ],
        ),
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
  RealtimeChannel? _commentsRealtimeChannel;

  int _likeCount = 0;
  int _dislikeCount = 0;
  int _userRating = 0;
  double _avgRating = 0.0;
  bool _hasRated = false;
  bool _showAudioWarning = true;
  bool _showIntroOverlay = true;

  final TextEditingController _commentController = TextEditingController();
  String? _replyingToCommentId;
  final TextEditingController _replyController = TextEditingController();
  String? _editingCommentId;
  final TextEditingController _editCommentController = TextEditingController();

  final TextEditingController _notesController = TextEditingController();
  bool _notesSaved = false;

  LiveClassModel? _localClassData;
  bool _isLoadingClassData = true;

  String _activeTab = 'Overview'; // 'Overview', 'Chapters', 'Resources', 'Notes'

  List<Map<String, dynamic>> _chapters = [];
  List<Map<String, dynamic>> _resources = [];
  List<Map<String, dynamic>> _relatedLectures = [];

  @override
  void initState() {
    super.initState();
    _viewInstanceKey =
        '${widget.classId}-${DateTime.now().millisecondsSinceEpoch}';
    _loadClassDataAndComments();
    _subscribeRealtimeComments();
  }

  @override
  void didUpdateWidget(StudentLiveClassPlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.classId != widget.classId) {
      _unsubscribeRealtimeComments();
      _viewInstanceKey =
          '${widget.classId}-${DateTime.now().millisecondsSinceEpoch}';
      _loadClassDataAndComments();
      _subscribeRealtimeComments();
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
    _loadRelatedLectures();

    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.get('/live-classes/${widget.classId}/playback-info', useCache: false);
      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];
        if (mounted) {
          setState(() {
            _localClassData = LiveClassModel.fromJson(data);
            _likeCount = data['like_count'] ?? 0;
            _dislikeCount = data['dislike_count'] ?? 0;
            _isLiked = data['is_liked'] ?? false;
            _isDisliked = data['is_disliked'] ?? false;
            _avgRating = (data['avg_rating'] as num?)?.toDouble() ?? 0.0;
            _userRating = data['user_rating'] ?? 0;
            _hasRated = data['has_rated'] ?? false;
            
            // Map chapters
            final List<dynamic> chList = data['chapters'] ?? [];
            _chapters = chList.map((ch) {
              final int secs = ch['time_seconds'] ?? 0;
              final m = secs ~/ 60;
              final s = secs % 60;
              return {
                'id': ch['id']?.toString() ?? '',
                'time': '${m.toString().padLeft(2, "0")}:${s.toString().padLeft(2, "0")}',
                'seconds': secs,
                'title': ch['title']?.toString() ?? ''
              };
            }).toList();
            
            // Map resources
            final List<dynamic> resList = data['resources'] ?? [];
            _resources = resList.map((res) {
              return {
                'id': res['id']?.toString() ?? '',
                'title': res['title']?.toString() ?? 'Resource',
                'size': res['file_size']?.toString() ?? '2.0 MB',
                'file_url': res['file_url']?.toString() ?? '',
                'type': 'pdf'
              };
            }).toList();

            final String nText = data['notes_text'] ?? '';
            _notesController.text = nText;
            _notesSaved = nText.isNotEmpty;
            
            _isLoadingClassData = false;
            _showIntroOverlay = true;
          });
          _startIntroOverlayTimer();
          return;
        }
      }
    } catch (e) {
      debugPrint('[PlayerScreen] Failed to fetch from playback-info endpoint: $e');
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

  void _subscribeRealtimeComments() {
    try {
      final channelName = 'live-class-comments-${widget.classId}';
      
      _commentsRealtimeChannel = Supabase.instance.client.channel(channelName);
      
      _commentsRealtimeChannel!
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'live_class_comments',
            callback: (payload) {
              if (!mounted) return;
              
              if (payload.eventType == PostgresChangeEvent.delete) {
                final oldRecord = payload.oldRecord;
                final deletedId = oldRecord['id']?.toString();
                if (deletedId != null) {
                  // Check if this comment (or any reply) is in our local list of comments
                  bool isLocal = false;
                  for (var comment in _comments) {
                    if (comment['id']?.toString() == deletedId) {
                      isLocal = true;
                      break;
                    }
                    final replies = comment['replies'] as List?;
                    if (replies != null) {
                      for (var reply in replies) {
                        if (reply is Map && reply['id']?.toString() == deletedId) {
                          isLocal = true;
                          break;
                        }
                      }
                    }
                    if (isLocal) break;
                  }
                  
                  if (isLocal) {
                    debugPrint('[CommentsRealtime] Local comment/reply deleted. Refreshing comments.');
                    _loadComments();
                  }
                }
              } else {
                // For INSERT and UPDATE, the payload has the full record
                final newRecord = payload.newRecord;
                final recordClassId = newRecord['live_class_id']?.toString();
                if (recordClassId != null && recordClassId == widget.classId) {
                  debugPrint('[CommentsRealtime] Local comment/reply inserted/updated. Refreshing comments.');
                  _loadComments();
                }
              }
            },
          )
          .subscribe((status, [error]) {
            debugPrint('[CommentsRealtime] Subscription status: $status, error: $error');
          });
      debugPrint('[CommentsRealtime] Registered subscription for channel: $channelName');
    } catch (e) {
      debugPrint('[CommentsRealtime] Failed to subscribe: $e');
    }
  }

  void _unsubscribeRealtimeComments() {
    try {
      if (_commentsRealtimeChannel != null) {
        Supabase.instance.client.removeChannel(_commentsRealtimeChannel!);
        _commentsRealtimeChannel = null;
        debugPrint('[CommentsRealtime] Unsubscribed channel');
      }
    } catch (e) {
      debugPrint('[CommentsRealtime] Failed to unsubscribe: $e');
    }
  }

  Future<void> _loadRelatedLectures() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.get('/live-classes/${widget.classId}/related');
      if (response['success'] == true && response['data'] != null) {
        if (mounted) {
          setState(() {
            _relatedLectures = List<Map<String, dynamic>>.from(response['data']);
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading related lectures: $e');
    }
  }

  Future<void> _submitEditComment(String commentId) async {
    final text = _editCommentController.text.trim();
    if (text.isEmpty) return;
    
    final success = await ref
        .read(liveClassesProvider.notifier)
        .editComment(widget.classId, commentId, text);
        
    if (success) {
      setState(() {
        _editingCommentId = null;
      });
      _loadComments();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to edit comment.')),
        );
      }
    }
  }

  Future<void> _showDeleteConfirmation(String commentId) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text('Delete Comment', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
          content: const Text('Are you sure you want to delete this comment? This action cannot be undone.', style: TextStyle(color: Colors.white70, fontSize: 11.5)),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.white60, fontSize: 11)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                final success = await ref
                    .read(liveClassesProvider.notifier)
                    .deleteComment(widget.classId, commentId);
                if (success) {
                  _loadComments();
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Failed to delete comment.')),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              child: const Text('Delete', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
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

  Future<void> _updateRecordingDurationOnServer(int durationSec) async {
    final currentDurationStr = _localClassData?.date?.split('·').skip(1).firstOrNull?.trim();
    if (currentDurationStr == '1s' || currentDurationStr == '0s' || currentDurationStr == null || currentDurationStr.isEmpty) {
      try {
        final apiService = ref.read(apiServiceProvider);
        final response = await apiService.post(
          '/live-classes/${widget.classId}/recording/duration',
          {'duration': durationSec},
        );
        if (response['success'] == true) {
          debugPrint('[Player] Successfully updated database duration to $durationSec seconds');
          if (mounted) {
            setState(() {
              if (_localClassData != null) {
                final datePart = _localClassData!.date?.split('·').firstOrNull?.trim() ?? '';
                final h = durationSec ~/ 3600;
                final m = (durationSec % 3600) ~/ 60;
                final s = durationSec % 60;
                String durationStr;
                if (h > 0) {
                  durationStr = '${h}h ${m}m ${s}s';
                } else if (m > 0) {
                  durationStr = '${m}m ${s}s';
                } else {
                  durationStr = '${s}s';
                }
                final newDateStr = datePart.isNotEmpty ? '$datePart · $durationStr' : durationStr;
                
                _localClassData = LiveClassModel(
                  id: _localClassData!.id,
                  subject: _localClassData!.subject,
                  title: _localClassData!.title,
                  description: _localClassData!.description,
                  subjectName: _localClassData!.subjectName,
                  teacher: _localClassData!.teacher,
                  started: _localClassData!.started,
                  viewers: _localClassData!.viewers,
                  time: _localClassData!.time,
                  timeUntil: _localClassData!.timeUntil,
                  date: newDateStr,
                  icon: _localClassData!.icon,
                  color: _localClassData!.color,
                  isLive: _localClassData!.isLive,
                  type: _localClassData!.type,
                  streamUrl: _localClassData!.streamUrl,
                  recordingUrl: _localClassData!.recordingUrl,
                  platform: _localClassData!.platform,
                  meetingLink: _localClassData!.meetingLink,
                  teacherId: _localClassData!.teacherId,
                );
              }
            });
          }
        }
      } catch (e) {
        debugPrint('[Player] Failed to update duration on server: $e');
      }
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

    final videoUrl = _getEmbedUrl(resolvedUrl);

    registerVideoPlayerView(
      viewKey,
      resolvedUrl,
      isDirectVideo,
      videoUrl,
      (actualDurSec) {
        _updateRecordingDurationOnServer(actualDurSec);
      },
    );
  }

  void _seekVideo(int seconds) {
    if (kIsWeb) {
      try {
        final success = seekWebVideo(seconds);
        if (success) {
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
        final success = unmuteWebVideo();
        if (success) {
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

  void _setPointerEvents(bool enabled) {
    if (kIsWeb) {
      setWebPointerEvents(enabled);
    }
  }

  Future<void> _toggleLike() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.post('/live-classes/${widget.classId}/like', {});
      if (response['success'] == true) {
        setState(() {
          _likeCount = response['like_count'] ?? _likeCount;
          _dislikeCount = response['dislike_count'] ?? _dislikeCount;
          _isLiked = response['is_liked'] ?? false;
          _isDisliked = response['is_disliked'] ?? false;
        });
      }
    } catch (e) {
      debugPrint('Error toggling like: $e');
    }
  }

  Future<void> _toggleDislike() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.post('/live-classes/${widget.classId}/dislike', {});
      if (response['success'] == true) {
        setState(() {
          _likeCount = response['like_count'] ?? _likeCount;
          _dislikeCount = response['dislike_count'] ?? _dislikeCount;
          _isLiked = response['is_liked'] ?? false;
          _isDisliked = response['is_disliked'] ?? false;
        });
      }
    } catch (e) {
      debugPrint('Error toggling dislike: $e');
    }
  }

  Future<void> _submitRating(int stars) async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.post('/live-classes/${widget.classId}/rate', {'rating': stars});
      if (response['success'] == true) {
        setState(() {
          _userRating = stars;
          _hasRated = true;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⭐ Thank you for rating this lecture $stars stars!'),
              backgroundColor: const Color(0xFFF59E0B),
            ),
          );
        }
        _loadClassDataAndComments();
      } else if (response['status'] == 403 || response['detail']?.toString().contains('cannot rate') == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Instructors cannot rate their own sessions.'),
              backgroundColor: Color(0xFF92400E),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error submitting rating: $e');
    }
  }

  Future<void> _saveNotes() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final text = _notesController.text;
      final response = await apiService.post('/live-classes/${widget.classId}/notes', {'notes_text': text});
      if (response['success'] == true) {
        setState(() {
          _notesSaved = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ Notes successfully saved for this lecture.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error saving notes: $e');
    }
  }

  Future<void> _updateOverview(String newTitle, String newDesc) async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.put('/live-classes/${widget.classId}/overview', {
        'title': newTitle,
        'description': newDesc
      });
      if (response['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✓ Overview updated successfully!'), backgroundColor: Color(0xFF10B981)),
        );
        _loadClassDataAndComments();
      }
    } catch (e) {
      debugPrint('Error updating overview: $e');
    }
  }

  int _parseTimeString(String timeStr) {
    try {
      final cleanStr = timeStr.trim();
      final parts = cleanStr.split(':');
      if (parts.length == 2) {
        final m = int.tryParse(parts[0]) ?? 0;
        final s = int.tryParse(parts[1]) ?? 0;
        return m * 60 + s;
      } else if (parts.length == 3) {
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        final s = int.tryParse(parts[2]) ?? 0;
        return h * 3600 + m * 60 + s;
      }
      return int.tryParse(cleanStr) ?? 0;
    } catch (e) {
      debugPrint('Error parsing time string: $e');
      return 0;
    }
  }

  Future<void> _addChapter(String title, int seconds) async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.post('/live-classes/${widget.classId}/chapters', {
        'title': title,
        'time_seconds': seconds
      });
      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Chapter added successfully!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
        _loadClassDataAndComments();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to add chapter: ${response['detail'] ?? 'Unknown error'}'),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error adding chapter: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding chapter: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _deleteChapter(String chapterId) async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.delete('/live-classes/${widget.classId}/chapters/$chapterId');
      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Chapter deleted successfully!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
        _loadClassDataAndComments();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete chapter: ${response['detail'] ?? 'Unknown error'}'),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error deleting chapter: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting chapter: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _addResource(String title, String fileUrl, {String sizeStr = '2.0 MB'}) async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.post('/live-classes/${widget.classId}/resources', {
        'title': title,
        'file_url': fileUrl,
        'file_size': sizeStr
      });
      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Resource added successfully!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
        _loadClassDataAndComments();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to add resource: ${response['detail'] ?? 'Unknown error'}'),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error adding resource: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding resource: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _deleteResource(String resourceId) async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.delete('/live-classes/${widget.classId}/resources/$resourceId');
      if (response['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Resource deleted successfully!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
        _loadClassDataAndComments();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete resource: ${response['detail'] ?? 'Unknown error'}'),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error deleting resource: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting resource: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  void _showEditOverviewDialog(LiveClassModel classData) {
    final titleCtrl = TextEditingController(text: classData.title ?? classData.subject);
    final descCtrl = TextEditingController(text: classData.description ?? '');
    _setPointerEvents(false);
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 480,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 40,
                spreadRadius: 0,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Color(0xFF1E293B), Color(0xFF0F172A)]),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.edit_note_rounded,
                          color: Color(0xFF38BDF8), size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Edit Class Overview',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white38, size: 18),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              // Body
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildPremiumTextField(
                        controller: titleCtrl,
                        label: 'Class Title',
                        icon: Icons.title_rounded),
                    const SizedBox(height: 16),
                    _buildPremiumTextField(
                        controller: descCtrl,
                        label: 'Description',
                        icon: Icons.description_rounded,
                        maxLines: 4),
                  ],
                ),
              ),
              // Footer
              Padding(
                padding:
                    const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildDialogButton(
                      label: 'Cancel',
                      onTap: () => Navigator.pop(ctx),
                      isPrimary: false,
                    ),
                    const SizedBox(width: 10),
                    _buildDialogButton(
                      label: 'Save Changes',
                      icon: Icons.check_rounded,
                      onTap: () {
                        Navigator.pop(ctx);
                        _updateOverview(titleCtrl.text, descCtrl.text);
                      },
                      isPrimary: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) => _setPointerEvents(true));
  }

  void _showAddChapterDialog() {
    final titleCtrl = TextEditingController();
    final timeCtrl = TextEditingController(text: '00:00');
    _setPointerEvents(false);
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 440,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 40,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                      colors: [Color(0xFF1E293B), Color(0xFF0F172A)]),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.playlist_add_rounded,
                          color: Color(0xFFEF4444), size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Add Timeline Chapter',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white38, size: 18),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildPremiumTextField(
                        controller: titleCtrl,
                        label: 'Chapter Title',
                        icon: Icons.bookmark_rounded),
                    const SizedBox(height: 16),
                    _buildPremiumTextField(
                        controller: timeCtrl,
                        label: 'Timestamp (MM:SS or HH:MM:SS)',
                        icon: Icons.schedule_rounded),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _buildDialogButton(
                      label: 'Cancel',
                      onTap: () => Navigator.pop(ctx),
                      isPrimary: false,
                    ),
                    const SizedBox(width: 10),
                    _buildDialogButton(
                      label: 'Add Chapter',
                      icon: Icons.add_circle_rounded,
                      onTap: () {
                        final title = titleCtrl.text.trim();
                        final timeStr = timeCtrl.text.trim();
                        if (title.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('⚠️ Chapter title cannot be empty'),
                              backgroundColor: Color(0xFFDC2626),
                            ),
                          );
                          return;
                        }
                        if (timeStr.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('⚠️ Timestamp cannot be empty'),
                              backgroundColor: Color(0xFFDC2626),
                            ),
                          );
                          return;
                        }
                        Navigator.pop(ctx);
                        final secs = _parseTimeString(timeStr);
                        _addChapter(title, secs);
                      },
                      isPrimary: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) => _setPointerEvents(true));
  }

  void _showAddResourceDialog() {
    final titleCtrl = TextEditingController();
    final urlCtrl =
        TextEditingController(text: '${AppConfig.baseUrl}/api/documents/download');
    
    // Picked file state
    Uint8List? pickedFileBytes;
    String pickedFileName = '';
    int pickedFileSize = 0;

    _setPointerEvents(false);
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          
          Future<void> pickLocalFile() async {
            try {
              final result = await FilePicker.platform.pickFiles(
                type: FileType.any,
                allowMultiple: false,
                withData: true,
              );
              if (result != null && result.files.single.bytes != null) {
                setDialogState(() {
                  pickedFileBytes = result.files.single.bytes;
                  pickedFileName = result.files.single.name;
                  pickedFileSize = result.files.single.size;
                  
                  // Auto-fill title if empty
                  if (titleCtrl.text.isEmpty) {
                    titleCtrl.text = pickedFileName.replaceAll(RegExp(r'\.[^.]+$'), '');
                  }
                  urlCtrl.text = pickedFileName;
                });
              }
            } catch (e) {
              debugPrint('Error picking file: $e');
            }
          }

          String getFileSizeString(int bytes) {
            if (bytes < 1024) return '$bytes B';
            if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
            return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: 440,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 40,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                          colors: [Color(0xFF1E293B), Color(0xFF0F172A)]),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.attach_file_rounded,
                              color: Color(0xFF10B981), size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Add Downloadable Resource',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white38, size: 18),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _buildPremiumTextField(
                            controller: titleCtrl,
                            label: 'Resource Name',
                            icon: Icons.description_rounded),
                        const SizedBox(height: 16),
                        
                        // Local File Section
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: pickedFileBytes != null
                                  ? const Color(0xFF10B981)
                                  : Colors.white.withValues(alpha: 0.06),
                            ),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Local Document Upload',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (pickedFileBytes != null)
                                    TextButton.icon(
                                      onPressed: () {
                                        setDialogState(() {
                                          pickedFileBytes = null;
                                          pickedFileName = '';
                                          pickedFileSize = 0;
                                          urlCtrl.text = '${AppConfig.baseUrl}/api/documents/download';
                                        });
                                      },
                                      icon: const Icon(Icons.clear_rounded, size: 12, color: Colors.redAccent),
                                      label: const Text('Clear', style: TextStyle(fontSize: 10, color: Colors.redAccent)),
                                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (pickedFileBytes == null)
                                ElevatedButton.icon(
                                  onPressed: pickLocalFile,
                                  icon: const Icon(Icons.upload_file_rounded, size: 14),
                                  label: const Text('Choose File from Device', style: TextStyle(fontSize: 11)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.15),
                                    foregroundColor: const Color(0xFF10B981),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                )
                              else
                                Row(
                                  children: [
                                    const Icon(Icons.insert_drive_file_rounded, color: Color(0xFF10B981), size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            pickedFileName,
                                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            getFileSizeString(pickedFileSize),
                                            style: const TextStyle(color: Colors.white38, fontSize: 9),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 16),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        if (pickedFileBytes == null)
                          _buildPremiumTextField(
                              controller: urlCtrl,
                              label: 'File URL / Download Link',
                              icon: Icons.link_rounded),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _buildDialogButton(
                          label: 'Cancel',
                          onTap: () => Navigator.pop(ctx),
                          isPrimary: false,
                        ),
                        const SizedBox(width: 10),
                        _buildDialogButton(
                          label: 'Add Resource',
                          icon: Icons.upload_file_rounded,
                          onTap: () async {
                            final title = titleCtrl.text.trim();
                            if (title.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('⚠️ Resource name cannot be empty'),
                                  backgroundColor: Color(0xFFDC2626),
                                ),
                              );
                              return;
                            }

                            Navigator.pop(ctx);

                            String fileUrl = '';
                            String fileSizeStr = '2.0 MB';

                            if (pickedFileBytes != null) {
                              try {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Uploading file to storage...'),
                                      backgroundColor: Color(0xFF38BDF8),
                                    ),
                                  );
                                }

                                final apiService = ref.read(apiServiceProvider);
                                final uploadRes = await apiService.multipartPostBytes(
                                  '/documents/upload',
                                  pickedFileBytes!,
                                  pickedFileName,
                                  'file',
                                  fields: {
                                    'title': title,
                                    'description': 'Uploaded for Live Class session',
                                    'category': 'my_uploads',
                                  },
                                );

                                if (uploadRes['success'] == true && uploadRes['data']?['document'] != null) {
                                  final doc = uploadRes['data']['document'];
                                  fileUrl = doc['file_url'] ?? '';
                                  final rawSize = doc['file_size'] as num?;
                                  fileSizeStr = getFileSizeString(rawSize?.toInt() ?? pickedFileSize);
                                } else {
                                  throw 'Upload response failed';
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('❌ File upload failed: $e'),
                                      backgroundColor: const Color(0xFFDC2626),
                                    ),
                                  );
                                }
                                return;
                              }
                            } else {
                              fileUrl = urlCtrl.text.trim();
                              if (fileUrl.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('⚠️ File URL / Download Link cannot be empty'),
                                    backgroundColor: Color(0xFFDC2626),
                                  ),
                                );
                                return;
                              }
                            }

                            _addResource(title, fileUrl, sizeStr: fileSizeStr);
                          },
                          isPrimary: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).then((_) => _setPointerEvents(true));
  }

  void _showShareModalDialog() {
    final searchCtrl = TextEditingController();
    List<Map<String, dynamic>> searchList = [];
    bool isSearching = false;
    _setPointerEvents(false);
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          Future<void> triggerSearch(String q) async {
            if (q.trim().isEmpty) {
              setDialogState(() {
                searchList = [];
              });
              return;
            }
            setDialogState(() {
              isSearching = true;
            });
            try {
              final apiService = ref.read(apiServiceProvider);
              final response = await apiService.get('/live-classes/school-users', query: {'search': q}, useCache: false);
              if (response['success'] == true && response['data'] != null) {
                if (dialogCtx.mounted) {
                  setDialogState(() {
                    searchList = List<Map<String, dynamic>>.from(response['data']);
                    isSearching = false;
                  });
                }
              }
            } catch (e) {
              if (dialogCtx.mounted) {
                setDialogState(() {
                  isSearching = false;
                });
              }
            }
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            child: Container(
              width: 480,
              height: 520,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 40,
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                          colors: [Color(0xFF1E293B), Color(0xFF0F172A)]),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.share_rounded,
                              color: Color(0xFF38BDF8), size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Share Class Recording',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close_rounded,
                              color: Colors.white38, size: 18),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  // Search bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: TextField(
                      controller: searchCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search school members...',
                        hintStyle:
                            const TextStyle(color: Colors.white24, fontSize: 12),
                        prefixIcon:
                            const Icon(Icons.search, color: Colors.white38, size: 18),
                        filled: true,
                        fillColor: const Color(0xFF1E293B),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Color(0xFF38BDF8), width: 1.5),
                        ),
                      ),
                      onChanged: triggerSearch,
                    ),
                  ),
                  // Results list
                  Expanded(
                    child: isSearching
                        ? const Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFF38BDF8)))
                        : searchList.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.group_outlined,
                                        color:
                                            Colors.white.withValues(alpha: 0.1),
                                        size: 48),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Search by name to find\nschool members',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: Colors.white24, fontSize: 12),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 4),
                                itemCount: searchList.length,
                                itemBuilder: (itemCtx, index) {
                                  final member = searchList[index];
                                  final name = member['full_name'] ?? 'User';
                                  final roleLabel =
                                      (member['role'] ?? 'student')
                                          .toString()
                                          .toUpperCase();
                                  return Container(
                                    margin:
                                        const EdgeInsets.symmetric(vertical: 4),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 34,
                                          height: 34,
                                          decoration: const BoxDecoration(
                                            gradient: LinearGradient(colors: [
                                              Color(0xFF4F46E5),
                                              Color(0xFF06B6D4)
                                            ]),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              name.isNotEmpty ? name[0] : '?',
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                  fontWeight:
                                                      FontWeight.bold),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(name,
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.bold)),
                                              Text(roleLabel,
                                                  style: const TextStyle(
                                                      color: Colors.white38,
                                                      fontSize: 9)),
                                            ],
                                          ),
                                        ),
                                        MouseRegion(
                                          cursor: SystemMouseCursors.click,
                                          child: GestureDetector(
                                            onTap: () async {
                                              Navigator.pop(ctx);
                                              try {
                                                final apiService =
                                                    ref.read(apiServiceProvider);
                                                final res = await apiService.post(
                                                  '/live-classes/${widget.classId}/share',
                                                  {'shared_to_id': member['id']},
                                                );
                                                if (res['success'] == true) {
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context)
                                                        .showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                            '✓ Shared with $name!'),
                                                        backgroundColor:
                                                            const Color(
                                                                0xFF10B981),
                                                      ),
                                                    );
                                                  }
                                                }
                                              } catch (e) {
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context)
                                                      .showSnackBar(
                                                    SnackBar(
                                                      content:
                                                          Text('Failed: $e'),
                                                      backgroundColor:
                                                          const Color(
                                                              0xFFEF4444),
                                                    ),
                                                  );
                                                }
                                              }
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 14, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF38BDF8)
                                                    .withValues(alpha: 0.15),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                    color: const Color(0xFF38BDF8)
                                                        .withValues(alpha: 0.3)),
                                              ),
                                              child: const Text(
                                                'Share',
                                                style: TextStyle(
                                                    color: Color(0xFF38BDF8),
                                                    fontSize: 11,
                                                    fontWeight:
                                                        FontWeight.bold),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                  ),
                  // Footer
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _buildDialogButton(
                          label: 'Close',
                          onTap: () => Navigator.pop(ctx),
                          isPrimary: false,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ).then((_) => _setPointerEvents(true));
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
    final isTeacher = ref.watch(authProvider).role == UserRole.teacher;

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
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                _buildPlayerArea(classData, isLive, isTeacher),
                const SizedBox(height: 16),
                // Autoplay Unmute Alert Banner
                if (_showAudioWarning && kIsWeb) ...[
                  _buildMuteWarningBanner(),
                  const SizedBox(height: 12),
                ],
                _buildTitleBlock(classData),
                const SizedBox(height: 16),
                _buildTabBar(),
                const SizedBox(height: 16),
                _buildTabContent(classData),
              ],
            ),
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
                    physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics()),
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
            physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics()),
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
              Positioned.fill(
                child: IgnorePointer(
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
    final String displayTitle =
        (classData.title != null && classData.title!.isNotEmpty)
            ? classData.title!
            : classData.subject;
    final String displaySub = classData.subjectName ?? classData.subject;
    final isTeacher = ref.watch(authProvider).role == UserRole.teacher;

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
            if (isTeacher) ...[
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.edit_rounded, color: Color(0xFF38BDF8), size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _showEditOverviewDialog(classData),
              ),
            ],
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
    final isTeacher = ref.watch(authProvider).role == UserRole.teacher;
    final auth = ref.watch(authProvider);
    // Check if this teacher owns this class (for rating restriction)
    final bool isOwnClass = isTeacher &&
        (auth.userData?['id'] != null &&
            classData.teacherId != null &&
            auth.userData!['id'].toString() == classData.teacherId.toString());

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
            ],
          ),
          const SizedBox(height: 16),

          // Action buttons: Like, Share
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
                        onTap: _toggleLike,
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
                        onTap: _toggleDislike,
                        borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(24),
                            bottomRight: Radius.circular(24)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          child: Row(
                            children: [
                              Icon(
                                _isDisliked
                                    ? Icons.thumb_down_rounded
                                    : Icons.thumb_down_outlined,
                                color: _isDisliked
                                    ? const Color(0xFFEF4444)
                                    : Colors.white70,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text('$_dislikeCount',
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Share Hub
                InkWell(
                  onTap: _showShareModalDialog,
                  borderRadius: BorderRadius.circular(24),
                  child: _buildActionBadge(
                    Icons.share_rounded,
                    'Share Hub',
                  ),
                ),
                const SizedBox(width: 8),

                // Copy Link
                InkWell(
                  onTap: () {
                    final String path = getWebWindowUrl();
                    Clipboard.setData(ClipboardData(text: path));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('🔗 Playback share link copied to clipboard!'),
                        backgroundColor: Color(0xFF10B981),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(24),
                  child: _buildActionBadge(
                    Icons.link_rounded,
                    'Copy Link',
                  ),
                ),
              ],
            ),
          ),

          // Rating Section
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isOwnClass
                          ? 'Session rating (yours):'
                          : 'Rate this lecture session:',
                      style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                    if (_avgRating > 0)
                      Text(
                        '⭐ ${_avgRating.toStringAsFixed(1)} average',
                        style: const TextStyle(
                            color: Color(0xFFF59E0B),
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (isOwnClass)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '⚠️ Instructors cannot rate their own sessions.',
                      style: TextStyle(
                          color: Color(0xFFF59E0B),
                          fontSize: 10,
                          fontStyle: FontStyle.italic),
                    ),
                  )
                else
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
                        onPressed: _hasRated ? null : () => _submitRating(starValue),
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
    final List<String> tabs = ['Overview', 'Chapters', 'Resources', 'Notes'];
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
    final isTeacher = ref.watch(authProvider).role == UserRole.teacher;

    switch (_activeTab) {
      case 'Chapters':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Lecture Timeline Chapters',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
                if (isTeacher)
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF38BDF8), size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _showAddChapterDialog,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_chapters.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text('No timeline chapters defined.', style: TextStyle(color: Colors.white38, fontSize: 11)),
                ),
              )
            else
              ..._chapters.map((ch) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                    clipBehavior: Clip.antiAlias,
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
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isTeacher)
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 16),
                              onPressed: () => _deleteChapter(ch['id']),
                            ),
                          const Icon(Icons.play_circle_fill_rounded,
                              color: Colors.white30, size: 18),
                        ],
                      ),
                      onTap: () => _seekVideo(ch['seconds']),
                    ),
                  ),
                );
              }),
          ],
        );
      case 'Resources':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Downloadable Lecture Materials',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold)),
                if (isTeacher)
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF38BDF8), size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _showAddResourceDialog,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_resources.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text('No resources available for download.', style: TextStyle(color: Colors.white38, fontSize: 11)),
                ),
              )
            else
              ..._resources.map((res) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                    clipBehavior: Clip.antiAlias,
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
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isTeacher) ...[
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 16),
                              onPressed: () => _deleteResource(res['id']),
                            ),
                            const SizedBox(width: 4),
                          ],
                          const Icon(Icons.download_rounded,
                              color: Color(0xFF38BDF8), size: 18),
                        ],
                      ),
                      onTap: () {
                        final url = res['file_url'];
                        if (url != null && url.isNotEmpty) {
                          try {
                            final uri = Uri.parse(_fixStorageUrl(url));
                            launchUrl(uri, mode: LaunchMode.externalApplication);
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Could not open resource: $e')),
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('📥 Downloading ${res['title']}...'),
                                backgroundColor: const Color(0xFF38BDF8)),
                          );
                        }
                      },
                    ),
                  ),
                );
              }),
          ],
        );
      case 'Notes':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                isTeacher
                    ? 'Take session notes (shared with students):'
                    : 'Session notes (view-only):',
                style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            TextField(
              controller: _notesController,
              enabled: isTeacher,
              maxLines: 6,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                hintText: isTeacher
                    ? 'Type your lecture summary, key formulas or remarks here...'
                    : 'No notes added for this lecture yet.',
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
                fillColor: const Color(0xFF1E293B),
                filled: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none),
              ),
              onChanged: (text) {
                if (_notesSaved) {
                  setState(() {
                    _notesSaved = false;
                  });
                }
              },
            ),
            if (isTeacher) ...[
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _notesSaved ? '✓ Saved successfully' : 'Unsaved changes',
                    style: TextStyle(
                        color: _notesSaved
                            ? const Color(0xFF10B981)
                            : Colors.white24,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    onPressed: _saveNotes,
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
          ],
        );
      case 'Overview':
      default:
        final String displayDesc = (classData.description != null &&
                classData.description!.isNotEmpty)
            ? classData.description!
            : 'Welcome to this recorded lecture session. In this session, we investigate deep curriculum concepts, go through live practice files, and check step-by-step calculations. Review resources and seek direct chapters to skip ahead.';
        
        final durationVal = classData.toJson().containsKey('duration') ? classData.toJson()['duration'] : null;
        String durationDisplay = "Recorded";
        if (durationVal != null) {
          final int totalSecs = (durationVal as num).toInt();
          final int h = totalSecs ~/ 3600;
          final int m = (totalSecs % 3600) ~/ 60;
          final int s = totalSecs % 60;
          if (h > 0) {
            durationDisplay = '${h}h ${m}m ${s}s';
          } else if (m > 0) {
            durationDisplay = '${m}m ${s}s';
          } else {
            durationDisplay = '${s}s';
          }
        } else {
          durationDisplay = classData.date?.split('·').skip(1).firstOrNull?.trim() ?? "Recorded";
        }

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
                '$durationDisplay (${classData.date?.split('·').firstOrNull ?? "Recorded Class"})'),
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

  /// Premium styled text field for dialogs
  Widget _buildPremiumTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      decoration: InputDecoration(
        labelText: label,
        labelStyle:
            const TextStyle(color: Colors.white38, fontSize: 12),
        prefixIcon: Icon(icon, color: Colors.white24, size: 18),
        filled: true,
        fillColor: const Color(0xFF1E293B),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF38BDF8), width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
    );
  }

  /// Premium styled button for dialogs
  Widget _buildDialogButton({
    required String label,
    required VoidCallback onTap,
    required bool isPrimary,
    IconData? icon,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            gradient: isPrimary
                ? const LinearGradient(
                    colors: [Color(0xFFEF4444), Color(0xFFDC2626)])
                : null,
            color: isPrimary ? null : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: isPrimary
                ? null
                : Border.all(
                    color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon,
                    color: isPrimary ? Colors.white : Colors.white54,
                    size: 14),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isPrimary ? Colors.white : Colors.white54,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarLecturesList() {
    if (_relatedLectures.isEmpty) return const SizedBox();

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
            itemCount: _relatedLectures.length,
            itemBuilder: (context, index) {
              final rec = _relatedLectures[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: const Color(0xFF1E293B),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.02)),
                  ),
                  clipBehavior: Clip.antiAlias,
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
                        child: Text(rec['icon']?.toString() ?? '📚',
                            style: const TextStyle(fontSize: 18)),
                      ),
                    ),
                    title: Text(
                      rec['subject']?.toString() ?? 'Related Lecture',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${rec['teacher'] ?? "Teacher"} · ${rec['date'] ?? "Recorded"}',
                      style: const TextStyle(color: Colors.white38, fontSize: 9),
                    ),
                    onTap: () {
                      final isTeacher =
                          ref.read(authProvider).role == UserRole.teacher;
                      final String routePath = isTeacher
                          ? '/teacher/live-classes/play/${rec['id']}'
                          : '/student/live-classes/play/${rec['id']}';
                      context.go(routePath);
                    },
                  ),
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

    final authState = ref.watch(authProvider);
    final currentUserId = authState.userData?['id']?.toString() ?? '';
    final commentUserId = comment['user_id']?.toString() ?? '';
    final bool isOwner = currentUserId.isNotEmpty &&
        commentUserId.isNotEmpty &&
        currentUserId.toLowerCase() == commentUserId.toLowerCase();
    
    debugPrint('[CommentsTest] commentId: $commentId, currentUserId: $currentUserId, commentUserId: $commentUserId, isOwner: $isOwner, commentText: ${comment['text']}');
    final bool canDelete = isOwner;
    final bool canEdit = isOwner;

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
                        Text(
                          '${comment['time'] ?? 'Just now'}${comment['is_edited'] == true ? ' · edited' : ''}',
                          style: const TextStyle(fontSize: 8, color: Colors.white24),
                        ),
                        if (canEdit || canDelete) ...[
                          const Spacer(),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert_rounded, size: 12, color: Colors.white38),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(maxWidth: 100),
                            color: const Color(0xFF1E293B),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            onSelected: (value) {
                              if (value == 'edit') {
                                setState(() {
                                  _editingCommentId = commentId;
                                  _editCommentController.text = comment['text'] ?? '';
                                });
                              } else if (value == 'delete') {
                                _showDeleteConfirmation(commentId);
                              }
                            },
                            itemBuilder: (context) => [
                              if (canEdit)
                                const PopupMenuItem(
                                  value: 'edit',
                                  height: 32,
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit_rounded, size: 12, color: Colors.white70),
                                      SizedBox(width: 6),
                                      Text('Edit', style: TextStyle(color: Colors.white70, fontSize: 10)),
                                    ],
                                  ),
                                ),
                              if (canDelete)
                                const PopupMenuItem(
                                  value: 'delete',
                                  height: 32,
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete_rounded, size: 12, color: Colors.redAccent),
                                      SizedBox(width: 6),
                                      Text('Delete', style: TextStyle(color: Colors.redAccent, fontSize: 10)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ]
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (_editingCommentId == commentId)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextField(
                              controller: _editCommentController,
                              style: const TextStyle(color: Colors.white, fontSize: 10.5),
                              maxLines: null,
                              decoration: InputDecoration(
                                fillColor: const Color(0xFF1E293B),
                                filled: true,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Colors.white10),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Colors.white10),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Color(0xFF38BDF8)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                ElevatedButton(
                                  onPressed: () => _submitEditComment(commentId),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF38BDF8),
                                    foregroundColor: Colors.black,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  ),
                                  child: const Text('Save', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 8),
                                TextButton(
                                  onPressed: () {
                                    setState(() {
                                      _editingCommentId = null;
                                    });
                                  },
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.white60,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text('Cancel', style: TextStyle(fontSize: 9)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    else
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
    _unsubscribeRealtimeComments();
    _commentController.dispose();
    _replyController.dispose();
    _editCommentController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}

