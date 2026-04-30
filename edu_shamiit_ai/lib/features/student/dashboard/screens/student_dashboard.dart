import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/services/api_service.dart';
import 'package:edu_shamiit_ai/core/providers/profile_provider.dart';
import 'package:edu_shamiit_ai/core/utils/responsive.dart';
import 'package:edu_shamiit_ai/shared/widgets/responsive_content.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/utils/l10n.dart';

class StudentDashboard extends ConsumerStatefulWidget {
  const StudentDashboard({super.key});

  @override
  ConsumerState<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends ConsumerState<StudentDashboard> {
  Map<String, dynamic>? _dashboardData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiService().get('/student/dashboard');
      final data = response.containsKey('data') ? response['data'] : response;
      
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
        {"title": "Timetable", "icon": "🗓️", "route": "/student/timetable", "bg": "EEF2FF"},
        {"title": "Results", "icon": "📊", "route": "/student/results", "bg": "FDF4FF"},
        {"title": "Fees", "icon": "💳", "route": "/student/fees", "bg": "ECFDF5"},
        {"title": "Notices", "icon": "📢", "route": "/student/notices", "bg": "FFF7ED"},
        {"title": "Homework", "icon": "📝", "route": "/student/homework", "bg": "FDF2F8"},
        {"title": "Transport", "icon": "🚌", "route": "/student/transport", "bg": "EFF6FF"},
        {"title": "Events", "icon": "📅", "route": "/student/events", "bg": "FEF3C7"},
        {"title": "Achieve", "icon": "🏆", "route": "/student/achievements", "bg": "F0FDF4"},
        {"title": "Attendance", "icon": "📋", "route": "/student/attendance", "bg": "EFF6FF"},
        {"title": "Library", "icon": "📖", "route": "/student/library", "bg": "FAF5FF"},
        {"title": "Courses", "icon": "📚", "route": "/student/courses", "bg": "ECFDF5"},
        {"title": "Leave", "icon": "✉️", "route": "/student/leave-application", "bg": "FEF2F2"},
        {"title": "Exams", "icon": "✍️", "route": "/student/exams", "bg": "EEF2FF"},
        {"title": "Live Class", "icon": "🔴", "route": "/student/live-classes", "bg": "FFE4E6", "badge": true},
        {"title": "Messages", "icon": "💬", "route": "/student/messaging", "bg": "E0E7FF"},
        {"title": "Leaderboard", "icon": "🏆", "route": "/student/leaderboard", "bg": "FEF3C7"},
        {"title": "Settings", "icon": "⚙️", "route": "/student/settings", "bg": "F1F5F9"},
      ],
    };
  }

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );

    final theme = Theme.of(context);

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

    final hour = DateTime.now().hour;
    final String greeting;
    final String greetingIcon;
    if (hour >= 5 && hour < 7) {
      greeting = 'Good Morning'.tr(ref);
      greetingIcon = '🌅'; // Dawn / early morning
    } else if (hour >= 7 && hour < 12) {
      greeting = 'Good Morning'.tr(ref);
      greetingIcon = '☀️'; // Sunny morning
    } else if (hour >= 12 && hour < 17) {
      greeting = 'Good Afternoon'.tr(ref);
      greetingIcon = '🌤️'; // Partly cloudy afternoon
    } else if (hour >= 17 && hour < 20) {
      greeting = 'Good Evening'.tr(ref);
      greetingIcon = '🌆'; // Early evening / sunset
    } else if (hour >= 20 && hour < 24) {
      greeting = 'Good Evening'.tr(ref);
      greetingIcon = '🌙'; // Night
    } else {
      greeting = 'Good Evening'.tr(ref);
      greetingIcon = '⭐'; // Late night / midnight
    }

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
                              '$greeting $greetingIcon',
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
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEF4444),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: const Color(0xFF4F46E5), width: 1.5),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          '3',
                                          style: TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
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
                              child: Hero(
                                tag: 'profile-avatar',
                                child: Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(9),
                                    child: avatarUrl != null && avatarUrl.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: avatarUrl,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) => Container(
                                              color: Colors.white.withValues(alpha: 0.1),
                                              child: Center(
                                                child: Text(
                                                  user['avatar_emoji'] ?? '🧑',
                                                  style: const TextStyle(fontSize: 18),
                                                ),
                                              ),
                                            ),
                                            errorWidget: (context, url, error) => Center(
                                              child: Text(
                                                user['avatar_emoji'] ?? '🧑',
                                                style: const TextStyle(fontSize: 18),
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
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
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
                              Text('🔥 Learning Streak'.tr(ref),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text('Keep it going!'.tr(ref),
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
                              Text('days'.tr(ref),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem('${stats['attendance_pct'] ?? 0}%', 'Attend.'.tr(ref), route: '/student/attendance'),
                        _buildStatItem('${stats['avg_score'] ?? 0}', 'Avg Score'.tr(ref), route: '/student/results'),
                        _buildStatItem('${stats['class_rank'] ?? '-'}${_getOrdinalSuffix(stats['class_rank'])}', 'Rank'.tr(ref), route: '/student/leaderboard'),
                        _buildStatItem('${stats['xp_points'] ?? 0}', 'XP Points'.tr(ref), route: '/student/leaderboard'),
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

  String _getOrdinalSuffix(int? n) {
    if (n == null) return '';
    if (n >= 11 && n <= 13) return 'th';
    switch (n % 10) {
      case 1: return 'st';
      case 2: return 'nd';
      case 3: return 'rd';
      default: return 'th';
    }
  }

  Widget _buildStatItem(String value, String label, {String? route}) {
    return GestureDetector(
      onTap: () => route != null ? context.push(route) : null,
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.6))),
        ],
      ),
    );
  }

  Widget _buildQuickAccessGrid() {
    final quickAccess = _dashboardData!['quick_access'] as List;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Access'.tr(ref),
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
                      (item['title'] as String).tr(ref),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Today''s Classes'.tr(ref),
              style: const TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/student/timetable'),
              child: Text('View All →'.tr(ref), style: const TextStyle(fontSize: 12, color: StudentColors.primary)),
            ),
          ],
        ),
        ...schedule.map((item) => _buildScheduleCard(item)),
      ],
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: StudentColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: Text(item['icon'], style: const TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['subject'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Text('${item['start_time']} - ${item['end_time']} | ${item['teacher']}', style: const TextStyle(fontSize: 11, color: StudentColors.text3)),
              ],
            ),
          ),
          if (item['is_now'] == true)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('● Ongoing'.tr(ref), style: const TextStyle(color: Colors.red, fontSize: 9, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildAiInsightCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7)]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('🤖 AI INSIGHT'.tr(ref), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF166534))),
          const SizedBox(height: 8),
          const Text('You have a Math homework due today. Based on your past performance, you might need about 45 mins to complete it.', 
               style: TextStyle(fontSize: 12, color: Color(0xFF166534), height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildPendingHomework() {
    final homework = _dashboardData!['pending_homework'] as List;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Pending Homework'.tr(ref),
              style: const TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/student/homework'),
              child: Text('View All →'.tr(ref), style: const TextStyle(fontSize: 12, color: StudentColors.primary)),
            ),
          ],
        ),
        ...homework.map((hw) => _buildHomeworkCard(hw)),
      ],
    );
  }

  Widget _buildHomeworkCard(Map<String, dynamic> hw) {
    return GestureDetector(
      onTap: () => context.push('/student/homework'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Text(hw['icon'], style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(hw['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('${hw['subject']} | Due: ${hw['due_date']}', style: const TextStyle(fontSize: 11, color: StudentColors.text3)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: StudentColors.text3),
          ],
        ),
      ),
    );
  }
}
