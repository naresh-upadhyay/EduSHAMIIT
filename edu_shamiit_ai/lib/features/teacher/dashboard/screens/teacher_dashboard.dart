import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_ai/core/constants/student_colors.dart';
import 'package:edu_shamiit_ai/core/constants/app_fonts.dart';
import 'package:edu_shamiit_ai/core/constants/app_gradients.dart';
import 'package:edu_shamiit_ai/shared/widgets/ai_fab.dart';

class TeacherDashboard extends ConsumerStatefulWidget {
  const TeacherDashboard({super.key});

  @override
  ConsumerState<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends ConsumerState<TeacherDashboard> {
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
          "full_name": "Dr. Priya Sharma",
          "subject": "Physics",
          "classes": ["X-A", "X-B", "XI-Science"],
          "xp_points": 3200,
          "streak": 25,
          "avatar_url": "",
        },
        "stats": {
          "attendance_pct": 96.0,
          "avg_score": 88.5,
          "classes_count": 3,
          "students_count": 120,
        },
        "today_schedule": [
          {
            "subject": "Physics",
            "icon": "⚛️",
            "class": "X-A",
            "start_time": "08:00",
            "end_time": "08:45",
            "room": "101",
            "is_now": true
          },
          {
            "subject": "Physics",
            "icon": "⚛️",
            "class": "X-B",
            "start_time": "09:00",
            "end_time": "09:45",
            "room": "102",
            "is_now": false
          },
        ],
        "pending_tasks": [
          {
            "id": "uuid-task-1",
            "title": "Grade Physics Test",
            "class": "X-A",
            "icon": "📝",
            "due_date": "2026-04-05",
            "status": "pending",
            "count": 45
          },
          {
            "id": "uuid-task-2",
            "title": "Submit Lesson Plans",
            "class": "All",
            "icon": "📋",
            "due_date": "2026-04-07",
            "status": "pending",
            "count": 3
          },
        ],
        "quick_access": [
          {"title": "Timetable", "icon": "📅", "route": "/teacher/timetable"},
          {"title": "Gradebook", "icon": "📊", "route": "/teacher/gradebook"},
          {"title": "My Classes", "icon": "👥", "route": "/teacher/my-classes"},
          {"title": "Homework", "icon": "📝", "route": "/teacher/homework"},
          {"title": "Notices", "icon": "📢", "route": "/teacher/notices"},
          {"title": "Attendance", "icon": "✅", "route": "/teacher/attendance"},
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
                      _buildPendingTasks(),
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
                            'Welcome, ${user['full_name']}! 👋',
                            style: const TextStyle(
                              fontFamily: AppFonts.heading,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${user['subject']} • ${user['classes'].length} Classes',
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
                                    child: Text('5', style: TextStyle(color: Colors.white, fontSize: 10)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          const CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.white30,
                            child: Text('👨‍🏫', style: TextStyle(fontSize: 20)),
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
                      _buildStatItem('📝', '${stats['avg_score']}', 'Avg Score'),
                      _buildStatItem('👥', '${stats['students_count']}', 'Students'),
                      _buildStatItem('⭐', '${user['xp_points']}', 'XP'),
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
              "Today's Classes",
              style: TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextButton(
              onPressed: () => context.push('/teacher/timetable'),
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
                  'Class ${item['class']} • Room ${item['room']}',
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

  Widget _buildPendingTasks() {
    final tasks = _dashboardData!['pending_tasks'] as List;

    if (tasks.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Pending Tasks',
              style: TextStyle(
                fontFamily: AppFonts.heading,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            TextButton(
              onPressed: () {},
              child: const Text('View All'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...tasks.map((task) => _buildTaskCard(task)),
      ],
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task) {
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
          Text(task['icon'], style: const TextStyle(fontSize: 28)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task['title'],
                  style: const TextStyle(
                    fontFamily: AppFonts.heading,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${task['class']} • ${task['count']} submissions',
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
              color: StudentColors.warningBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Due: ${task['due_date']}',
              style: const TextStyle(
                color: StudentColors.warning,
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
          _buildNavItem('🏠', 'Home', true, '/teacher/dashboard'),
          _buildNavItem('📖', 'Classes', false, '/teacher/my-classes'),
          _buildNavItem('📊', 'Grades', false, '/teacher/gradebook'),
          _buildNavItem('📝', 'Tasks', false, '/teacher/homework'),
          _buildNavItem('👤', 'Profile', false, '/teacher/profile'),
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