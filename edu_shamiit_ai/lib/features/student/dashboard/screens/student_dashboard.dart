import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/constants/app_gradients.dart';
import 'package:edu_shamiit_ai/core/services/api_service.dart';
import 'package:edu_shamiit_ai/core/providers/profile_provider.dart';
import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:edu_shamiit_ai/shared/widgets/responsive_content.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/shared/widgets/ai_fab.dart';
import 'package:edu_shamiit_ai/core/utils/l10n.dart';

class StudentDashboard extends ConsumerStatefulWidget {
  const StudentDashboard({super.key});

  @override
  ConsumerState<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends ConsumerState<StudentDashboard> {
  Map<String, dynamic>? _dashboardData;
  bool _isLoading = true;
  String _greeting = 'Hello';

  @override
  void initState() {
    super.initState();
    _setGreeting();
    _loadDashboard();
  }

  void _setGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      _greeting = 'Good Morning';
    } else if (hour < 17) {
      _greeting = 'Good Afternoon';
    } else {
      _greeting = 'Good Evening';
    }
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Try to fetch from API first
      final response = await ApiService().get('/student/dashboard');
      final data = response.containsKey('data') ? response['data'] : response;
      
      // Ensure Settings is in quick access
      if (data != null && data is Map && data.containsKey('quick_access')) {
        final List quickAccess = List.from(data['quick_access']);
        final hasSettings = quickAccess.any((item) => item['title'] == 'Settings');
        if (!hasSettings) {
          quickAccess.add({
            "title": "Settings",
            "icon": "⚙️",
            "route": "/student/settings",
            "bg": "F1F5F9"
          });
          data['quick_access'] = quickAccess;
        }
      }

      setState(() {
        _dashboardData = data;
        _isLoading = false;
      });
    } catch (e) {
      // Fallback to mock data if API fails
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() {
        _dashboardData = _getMockData();
        _isLoading = false;
      });
    }
  }

  Map<String, dynamic> _getMockData() {
    return {
      "user": {
        "full_name": "Arjun Kumar",
        "class": "X-A",
        "roll_no": "18",
        "session": "2024-25",
        "xp_points": 2450,
        "learning_streak": 18,
        "avatar_emoji": "🧑",
      },
      "stats": {
        "attendance_pct": 94.0,
        "avg_score": 91.4,
        "class_rank": 3,
        "xp_points": 2450,
      },
      "today_schedule": [
        {
          "subject": "Mathematics",
          "icon": "📐",
          "start_time": "8:00",
          "end_time": "9:00",
          "room": "301",
          "teacher": "Mr. R. Sharma",
          "is_now": false,
        },
        {
          "subject": "Physics",
          "icon": "⚛️",
          "start_time": "9:00",
          "end_time": "10:00",
          "room": "Lab 2",
          "teacher": "Dr. A. Verma",
          "is_now": true,
        },
        {
          "subject": "English",
          "icon": "📖",
          "start_time": "10:20",
          "end_time": "11:20",
          "room": "204",
          "teacher": "Ms. P. Gupta",
          "is_now": false,
        },
      ],
      "pending_homework": [
        {
          "id": "hw-1",
          "title": "Integration Practice Set — Chapter 7",
          "subject": "Mathematics",
          "icon": "📐",
          "due_date": "TODAY 5 PM",
          "status": "due_today",
          "problems": "5 problems",
        },
        {
          "id": "hw-2",
          "title": "Titration Lab Report — Acid-Base",
          "subject": "Chemistry",
          "icon": "⚗️",
          "due_date": "Tomorrow",
          "status": "due_soon",
          "problems": "Lab Report",
        },
      ],
      "quick_access": [
        {"title": "Timetable".tr(ref), "icon": "🗓️", "route": "/student/timetable", "bg": "EEF2FF"},
        {"title": "Results".tr(ref), "icon": "📊", "route": "/student/results", "bg": "FDF4FF"},
        {"title": "Fees".tr(ref), "icon": "💳", "route": "/student/fees", "bg": "ECFDF5"},
        {"title": "Notices".tr(ref), "icon": "📢", "route": "/student/notices", "bg": "FFF7ED"},
        {"title": "Homework".tr(ref), "icon": "📝", "route": "/student/homework", "bg": "FDF2F8"},
        {"title": "Transport".tr(ref), "icon": "🚌", "route": "/student/transport", "bg": "EFF6FF"},
        {"title": "Events".tr(ref), "icon": "📅", "route": "/student/events", "bg": "FEF3C7"},
        {"title": "Achieve".tr(ref), "icon": "🏆", "route": "/student/achievements", "bg": "F0FDF4"},
        {"title": "Attendance".tr(ref), "icon": "📋", "route": "/student/attendance", "bg": "EFF6FF"},
        {"title": "Library".tr(ref), "icon": "📖", "route": "/student/library", "bg": "FAF5FF"},
        {"title": "Courses".tr(ref), "icon": "📚", "route": "/student/courses", "bg": "ECFDF5"},
        {"title": "Leave".tr(ref), "icon": "✉️", "route": "/student/leave-application", "bg": "FEF2F2"},
        {"title": "Exams".tr(ref), "icon": "✍️", "route": "/student/exams", "bg": "EEF2FF"},
        {"title": "Live Class".tr(ref), "icon": "🔴", "route": "/student/live-classes", "bg": "FFE4E6", "badge": true},
        {"title": "Messages".tr(ref), "icon": "💬", "route": "/student/messaging", "bg": "E0E7FF"},
        {"title": "Leaderboard".tr(ref), "icon": "🏆", "route": "/student/leaderboard", "bg": "FEF3C7"},
        {"title": "Settings".tr(ref), "icon": "⚙️", "route": "/student/settings", "bg": "F1F5F9"},
      ],
    };
  }

  @override
  Widget build(BuildContext context) {
    // Set system UI overlay style
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildHeader(),
              SliverToBoxAdapter(
                child: ResponsiveContent(
                  child: Padding(
                    padding: Responsive.contentPadding(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        _buildQuickAccessGrid(),
                        const SizedBox(height: 16),
                        _buildTodaySchedule(),
                        const SizedBox(height: 16),
                        _buildAiInsightCard(),
                        const SizedBox(height: 16),
                        _buildPendingHomework(),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final user = _dashboardData!['user'];
    final stats = _dashboardData!['stats'];
    final profileState = ref.watch(profileProvider);
    final profile = profileState.profile;
    final String? avatarUrl = profile?.avatarUrl ?? user['avatar_url'];
    final String fullName = profile?.name ?? user['full_name'] ?? 'Student';

    return SliverAppBar(
      expandedHeight: Responsive.headerExpandedHeight(context),
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF4F46E5), Color(0xFF302B63)],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_greeting.tr(ref)} 🌤️',
                              style: TextStyle(
                                fontFamily: AppFonts.body,
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              fullName,
                              style: const TextStyle(
                                fontFamily: AppFonts.heading,
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => context.push('/student/notifications'),
                              child: Stack(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.notifications_outlined,
                                      color: Colors.white,
                                      size: 18,
                                    ),
                                  ),
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Container(
                                      width: 16,
                                      height: 16,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFEF4444),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Center(
                                        child: Text(
                                          '3',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            GestureDetector(
                              onTap: () => context.push('/student/profile'),
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF06B6D4), Color(0xFF4F46E5)],
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    width: 2,
                                  ),
                                ),
                                child: ClipOval(
                                  child: avatarUrl != null && avatarUrl.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: avatarUrl,
                                          fit: BoxFit.cover,
                                          width: 40,
                                          height: 40,
                                          placeholder: (context, url) => Center(
                                            child: Text(
                                              fullName.isNotEmpty ? fullName[0].toUpperCase() : '🧑',
                                              style: const TextStyle(fontSize: 16, color: Colors.white),
                                            ),
                                          ),
                                          errorWidget: (context, url, error) => Center(
                                            child: Text(
                                              fullName.isNotEmpty ? fullName[0].toUpperCase() : '🧑',
                                              style: const TextStyle(fontSize: 16, color: Colors.white),
                                            ),
                                          ),
                                        )
                                      : Center(
                                          child: Text(
                                            user['avatar_emoji'] ?? '🧑',
                                            style: const TextStyle(fontSize: 18),
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Learning streak
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '🔥 Learning Streak',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Keep it going!',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Text(
                                '${user['learning_streak'] ?? 0}',
                                style: const TextStyle(
                                  fontFamily: AppFonts.heading,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFF59E0B),
                                ),
                              ),
                              Text(
                                'days',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.white.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Stats row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem('${stats['attendance_pct'] ?? 0}%', 'Attend.', route: '/student/attendance'),
                        _buildStatItem('${stats['avg_score'] ?? 0}', 'Avg Score', route: '/student/results'),
                        _buildStatItem('${stats['class_rank'] ?? '-'}${_getOrdinalSuffix(stats['class_rank'])}', 'Rank', route: '/student/leaderboard'),
                        _buildStatItem('${stats['xp_points'] ?? 0}', 'XP Points', route: '/student/leaderboard'),
                      ],
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


  Widget _buildStatItem(String value, String label, {String? route}) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontFamily: AppFonts.heading,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );

    if (route != null) {
      return Expanded(
        child: GestureDetector(
          onTap: () => context.push(route),
          child: child,
        ),
      );
    }
    return Expanded(child: child);
  }

  String _getOrdinalSuffix(dynamic rank) {
    if (rank == null) return '';
    int? n = int.tryParse(rank.toString());
    if (n == null) return '';
    if (n % 100 >= 11 && n % 100 <= 13) return 'th';
    switch (n % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }

  Widget _buildQuickAccessGrid() {
    final quickAccess = _dashboardData!['quick_access'] as List;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Access',
          style: TextStyle(
            fontFamily: AppFonts.heading,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: Responsive.gridCrossAxisCount(context),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: Responsive.gridChildAspectRatio(context),
          ),
          itemCount: quickAccess.length,
          itemBuilder: (context, index) {
            final item = quickAccess[index];
            return GestureDetector(
              onTap: () => context.push(item['route']),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: Color(int.parse(item['bg'] ?? 'EEF2FF', radix: 16)).withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Center(
                        child: Stack(
                          children: [
                            Text(item['icon'], style: const TextStyle(fontSize: 20)),
                            if (item['badge'] == true)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEF4444),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item['title'],
                      style: TextStyle(
                        fontFamily: AppFonts.body,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? StudentColors.darkText2 : const Color(0xFF475569),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTodaySchedule() {
    final schedule = _dashboardData!['today_schedule'] as List;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          if (Theme.of(context).brightness != Brightness.dark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Today's Schedule",
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white 
                    : const Color(0xFF0F172A),
                ),
              ),
              TextButton(
                onPressed: () => context.push('/student/timetable'),
                child: const Text(
                  'View All →',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF4F46E5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...schedule.map((item) => _buildScheduleCard(item)),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> item) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isNow = item['is_now'] == true;
    final String startTime = item['start_time']?.toString() ?? '--:--';
    final String endTime = item['end_time']?.toString() ?? '--:--';
    final String subjectName = item['subject'] ?? item['subjects']?['name'] ?? 'Subject';
    final String room = item['room']?.toString() ?? 'TBD';
    final String teacher = item['teacher'] ?? item['profiles']?['full_name'] ?? 'TBD';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isNow 
          ? (isDark ? StudentColors.primary.withOpacity(0.1) : const Color(0xFFF0FFF4)) 
          : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Column(
            children: [
              Text(
                startTime,
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: isNow ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8),
                ),
              ),
              Text(
                endTime,
                style: TextStyle(
                  fontSize: 9,
                  color: isNow ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const SizedBox(width: 10),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isNow ? const Color(0xFF059669) : const Color(0xFF4F46E5),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subjectName,
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  'Room $room · $teacher',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          if (isNow)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '● Ongoing',
                style: TextStyle(
                  color: Color(0xFF059669),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAiInsightCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
            ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
            : [const Color(0xFFEEF2FF), const Color(0xFFF0FDFF)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? StudentColors.darkBorder : const Color(0xFFE0E7FF), 
          width: 1.5
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '🤖 AI INSIGHT',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your Physics score improved by 8% this month! Focus on Optics — there\'s a 78% chance it appears in your upcoming exam.',
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontSize: 12,
              color: isDark ? StudentColors.darkText2 : const Color(0xFF3730A3),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingHomework() {
    final homework = _dashboardData!['pending_homework'] as List;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          if (Theme.of(context).brightness != Brightness.dark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pending Homework',
                style: TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white 
                    : const Color(0xFF0F172A),
                ),
              ),
              TextButton(
                onPressed: () => context.push('/student/homework'),
                child: const Text(
                  '3 tasks',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF4F46E5),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...homework.map((hw) => _buildHomeworkCard(hw)),
        ],
      ),
    );
  }

  Widget _buildHomeworkCard(Map<String, dynamic> hw) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isUrgent = hw['status'] == 'due_today';
    final String icon = hw['icon'] ?? hw['subjects']?['icon'] ?? '📝';
    final String title = hw['title'] ?? 'Homework';
    final String subjectName = hw['subject'] ?? hw['subjects']?['name'] ?? 'Subject';
    final String dueDate = hw['due_date']?.toString() ?? 'TBD';

    return GestureDetector(
      onTap: () => context.push('/student/homework'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isUrgent ? const Color(0xFFEF4444).withValues(alpha: 0.2) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isUrgent ? const Color(0xFFEEF2FF) : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(icon, style: const TextStyle(fontSize: 14)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subjectName,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              dueDate,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isUrgent ? const Color(0xFFEF4444) : const Color(0xFFD97706),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
