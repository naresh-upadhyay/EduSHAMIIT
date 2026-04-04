import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/constants/app_gradients.dart';
import 'package:edu_shamiit_ai/shared/widgets/ai_fab.dart';

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
    // TODO: Call real API from backend
    await Future.delayed(const Duration(milliseconds: 500));

    setState(() {
      _dashboardData = {
        "user": {
          "full_name": "Rohan Sharma",
          "class": "X-A",
          "xp_points": 2450,
          "learning_streak": 18,
          "avatar_url": "",
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
            "start_time": "08:00",
            "end_time": "08:45",
            "room": "101",
            "is_now": true
          },
          {
            "subject": "Physics",
            "icon": "⚛️",
            "start_time": "09:00",
            "end_time": "09:45",
            "room": "Lab-1",
            "is_now": false
          },
        ],
        "pending_homework": [
          {
            "id": "uuid-hw-1",
            "title": "Trigonometry Problems",
            "subject": "Mathematics",
            "icon": "📐",
            "due_date": "2026-04-05",
            "status": "due_soon"
          }
        ],
        "quick_access": [
          {"title": "Timetable", "icon": "📅", "route": "/student/timetable"},
          {"title": "Results", "icon": "📊", "route": "/student/results"},
          {"title": "Fees", "icon": "💰", "route": "/student/fees"},
          {"title": "Notices", "icon": "📢", "route": "/student/notices"},
          {"title": "Homework", "icon": "📝", "route": "/student/homework"},
          {"title": "Transport", "icon": "🚌", "route": "/student/transport"},
          {"title": "Events", "icon": "🎉", "route": "/student/events"},
          {"title": "Attendance", "icon": "📊", "route": "/student/attendance"},
        ],
      };
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FF),
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _buildHeader(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      _buildQuickAccessGrid(),
                      const SizedBox(height: 20),
                      _buildTodaySchedule(),
                      const SizedBox(height: 20),
                      _buildAiInsightCard(),
                      const SizedBox(height: 20),
                      _buildPendingHomework(),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            bottom: 80,
            right: 16,
            child: AiFab(
              gradient: AppGradients.studentPrimary,
              onPressed: () => context.push('/ai-chat'),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader() {
    final user = _dashboardData!['user'];
    final stats = _dashboardData!['stats'];

    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: AppGradients.studentHeader,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
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
                            'Hello, ${user['full_name']}! 👋',
                            style: const TextStyle(
                              fontFamily: AppFonts.heading,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Class ${user['class']} • Keep it up!',
                            style: TextStyle(
                              fontFamily: AppFonts.body,
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const Text('🔥', style: TextStyle(fontSize: 16)),
                                const SizedBox(width: 4),
                                Text(
                                  '${user['learning_streak']} days',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Stack(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.notifications_outlined, color: Colors.white),
                                onPressed: () {},
                              ),
                              Positioned(
                                right: 8,
                                top: 8,
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFEF4444),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: Text('3', style: TextStyle(color: Colors.white, fontSize: 10)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          const CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.white30,
                            child: Text('👨‍🎓', style: TextStyle(fontSize: 20)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem('📊', '${stats['attendance_pct']}%', 'Attendance'),
                      _buildStatItem('📝', '${stats['avg_score']}', 'Score'),
                      _buildStatItem('🏆', '#${stats['class_rank']}', 'Rank'),
                      _buildStatItem('⭐', '${stats['xp_points']}', 'XP'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontFamily: AppFonts.heading,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontFamily: AppFonts.body,
            fontSize: 12,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAccessGrid() {
    final quickAccess = _dashboardData!['quick_access'] as List;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Access',
          style: TextStyle(
            fontFamily: AppFonts.heading,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: quickAccess.length,
          itemBuilder: (context, index) {
            final item = quickAccess[index];
            return GestureDetector(
              onTap: () => context.push(item['route']),
              child: Container(
                decoration: BoxDecoration(
                  color: StudentColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(item['icon'], style: const TextStyle(fontSize: 28)),
                    const SizedBox(height: 6),
                    Text(
                      item['title'],
                      style: const TextStyle(
                        fontFamily: AppFonts.body,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
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
            const Text(
              "Today's Schedule",
              style: TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/student/timetable'),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...schedule.map((item) => _buildScheduleCard(item)),
      ],
    );
  }

  Widget _buildScheduleCard(Map<String, dynamic> item) {
    final isNow = item['is_now'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: StudentColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: isNow ? Border.all(color: StudentColors.success, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            children: [
              Text(
                item['start_time'],
                style: const TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                item['end_time'],
                style: TextStyle(
                  fontFamily: AppFonts.body,
                  fontSize: 12,
                  color: StudentColors.text3,
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: StudentColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(item['icon'], style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      item['subject'],
                      style: const TextStyle(
                        fontFamily: AppFonts.heading,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Room ${item['room']}',
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 13,
                    color: StudentColors.text3,
                  ),
                ),
              ],
            ),
          ),
          if (isNow)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: StudentColors.successBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'NOW',
                style: TextStyle(
                  color: StudentColors.success,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAiInsightCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: StudentColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: StudentColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: AppGradients.studentPrimary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(child: Text('🤖', style: TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Shami AI Insight',
                  style: TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your Physics score improved by 5%! Keep practicing Newton\'s laws.',
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 13,
                    color: StudentColors.text2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingHomework() {
    final homework = _dashboardData!['pending_homework'] as List;

    if (homework.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Pending Homework',
              style: TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/student/homework'),
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...homework.map((hw) => _buildHomeworkCard(hw)),
      ],
    );
  }

  Widget _buildHomeworkCard(Map<String, dynamic> hw) {
    final isUrgent = hw['status'] == 'due_soon';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: StudentColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(hw['icon'], style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hw['title'],
                  style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${hw['subject']} • Due: ${hw['due_date']}',
                  style: TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 13,
                    color: StudentColors.text3,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isUrgent ? StudentColors.warningBg : StudentColors.infoBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              isUrgent ? 'Due Soon' : 'Pending',
              style: TextStyle(
                color: isUrgent ? StudentColors.warning : StudentColors.info,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: StudentColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem('🏠', 'Home', true, '/student/dashboard'),
          _buildNavItem('📖', 'Courses', false, '/student/courses'),
          _buildNavItem('📊', 'Results', false, '/student/results'),
          _buildNavItem('🏆', 'Achieve', false, '/student/achievements'),
          _buildNavItem('👤', 'Profile', false, '/student/profile'),
        ],
      ),
    );
  }

  Widget _buildNavItem(String emoji, String label, bool isActive, String route) {
    return GestureDetector(
      onTap: () => context.go(route),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: TextStyle(fontSize: 22, color: isActive ? StudentColors.primary : StudentColors.text3)),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: AppFonts.body,
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive ? StudentColors.primary : StudentColors.text3,
            ),
          ),
        ],
      ),
    );
  }
}