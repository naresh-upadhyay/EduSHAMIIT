import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:edu_shamiit_academic/core/services/teacher_api_service.dart';
import 'package:edu_shamiit_core/models/teacher_models.dart' as models;
import 'package:edu_shamiit_core/edu_shamiit_core.dart';

class TeacherDashboardScreen extends ConsumerStatefulWidget {
  const TeacherDashboardScreen({super.key});

  @override
  ConsumerState<TeacherDashboardScreen> createState() =>
      _TeacherDashboardScreenState();
}

class _TeacherDashboardScreenState
    extends ConsumerState<TeacherDashboardScreen> {
  final TeacherApiService _apiService = TeacherApiService();
  models.TeacherDashboard? _dashboardData;
  bool _isLoading = true;
  String? _error;
  int _unreadCount = 0;
  RealtimeChannel? _notifChannel;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  @override
  void dispose() {
    if (_notifChannel != null) {
      Supabase.instance.client.removeChannel(_notifChannel!);
    }
    super.dispose();
  }

  void _setupRealtimeNotifications(String userId) {
    _notifChannel = Supabase.instance.client
        .channel('teacher_dash_notif_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            if (!mounted) return;
            _refreshUnreadCount();
          },
        )
        .subscribe();
  }

  Future<void> _refreshUnreadCount() async {
    try {
      final notifications = await _apiService.getNotifications(isRead: false);
      if (!mounted) return;
      setState(() => _unreadCount = notifications.length);
    } catch (_) {}
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final dashboard = await _apiService.getDashboard();
      final notifications = await _apiService.getNotifications(isRead: false);
      if (!mounted) return;
      setState(() {
        _dashboardData = dashboard;
        _unreadCount = notifications.length;
        _isLoading = false;
      });
      // Setup realtime after we know the userId
      final userId = ref.read(authProvider).userData?['id'] as String?;
      if (userId != null && _notifChannel == null) {
        _setupRealtimeNotifications(userId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $_error', style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadDashboard,
                child: Text('Retry'.tr(ref)),
              ),
            ],
          ),
        ),
      );
    }

    if (_dashboardData == null) {
      return Scaffold(
        body: Center(child: Text('No data available'.tr(ref))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FF),
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
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final profileState = ref.watch(teacherProfileProvider);
    final profile = profileState.profile;

    final user = profile ?? _dashboardData!.user;
    final stats = _dashboardData!.stats;
    final profileImageUrl = user.profileImageUrl;

    final hour = DateTime.now().hour;
    final String greeting;
    final String greetingIcon;
    if (hour >= 5 && hour < 7) {
      greeting = 'Good Morning'.tr(ref);
      greetingIcon = '🌅';
    } else if (hour >= 7 && hour < 12) {
      greeting = 'Good Morning'.tr(ref);
      greetingIcon = '☀️';
    } else if (hour >= 12 && hour < 17) {
      greeting = 'Good Afternoon'.tr(ref);
      greetingIcon = '🌤️';
    } else if (hour >= 17 && hour < 20) {
      greeting = 'Good Evening'.tr(ref);
      greetingIcon = '🌆';
    } else if (hour >= 20 && hour < 24) {
      greeting = 'Good Evening'.tr(ref);
      greetingIcon = '🌙';
    } else {
      greeting = 'Good Evening'.tr(ref);
      greetingIcon = '⭐';
    }

    return SliverAppBar(
      expandedHeight: Responsive.headerExpandedHeight(context),
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
                            '$greeting $greetingIcon',
                            style: TextStyle(
                              fontFamily: AppFonts.body,
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user.fullName,
                            style: const TextStyle(
                              fontFamily: AppFonts.heading,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${user.subject} · ${user.specialization ?? 'Teacher'}',
                            style: TextStyle(
                              fontFamily: AppFonts.body,
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () async {
                              await context.push('/teacher/notifications');
                              _loadDashboard();
                            },
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
                                if (_unreadCount > 0)
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFEF4444),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: const Color(0xFF0C4A6E),
                                            width: 1.5),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '$_unreadCount',
                                          style: const TextStyle(
                                              fontSize: 8,
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          GestureDetector(
                            onTap: () async {
                              await context.push('/teacher/profile');
                              _loadDashboard();
                            },
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                  width: 1.5,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(9),
                                child: profileImageUrl != null &&
                                        profileImageUrl.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: profileImageUrl,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            Container(
                                          color: Colors.white
                                              .withValues(alpha: 0.1),
                                          child: const Center(
                                            child: Text('👨‍🏫',
                                                style: TextStyle(fontSize: 20)),
                                          ),
                                        ),
                                        errorWidget: (context, url, error) =>
                                            _initials(user.fullName),
                                      )
                                    : _initials(user.fullName),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem('${stats.studentsCount}', 'Students',
                          route: '/teacher/student-directory'),
                      _buildStatItem(
                          '${stats.attendancePct.toStringAsFixed(0)}%',
                          'Avg Attend.',
                          route: '/teacher/attendance'),
                      _buildStatItem('${stats.classesCount}', 'Classes',
                          route: '/teacher/my-classes'),
                      _buildStatItem('${stats.pendingGrading}', 'Pending',
                          route: '/teacher/homework'),
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

  Widget _buildStatItem(String value, String label, {String? route}) {
    return GestureDetector(
      onTap: () => route != null ? context.push(route) : null,
      child: Column(
        children: [
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
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAccessGrid() {
    final quickAccess = _dashboardData!.quickAccess;

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
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: Responsive.gridCrossAxisCount(context),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: Responsive.gridChildAspectRatio(context),
          ),
          itemCount: quickAccess.length,
          itemBuilder: (context, index) {
            final item = quickAccess[index];
            return GestureDetector(
              onTap: () => context.push(item.route),
              child: Container(
                decoration: BoxDecoration(
                  color: StudentColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
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
                    Text(item.icon, style: const TextStyle(fontSize: 28)),
                    const SizedBox(height: 6),
                    Text(
                      item.title,
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
    final schedule = _dashboardData!.todaySchedule;

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
              child: Text('View All'.tr(ref)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...schedule.map((item) => _buildScheduleCard(item)),
      ],
    );
  }

  Widget _buildScheduleCard(models.TeacherScheduleItem item) {
    final isNow = item.isNow;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: StudentColors.surface,
        borderRadius: BorderRadius.circular(14),
        border:
            isNow ? Border.all(color: StudentColors.success, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
                item.startTime,
                style: const TextStyle(
                  fontFamily: AppFonts.heading,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                item.endTime,
                style: const TextStyle(
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
                    Text(item.icon, style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      item.subject,
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
                  'Class ${item.class_} • Room ${item.room}',
                  style: const TextStyle(
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
    final tasks = _dashboardData!.pendingTasks;

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
              onPressed: () => context.push('/teacher/homework'),
              child: Text('View All'.tr(ref)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...tasks.map((task) => _buildTaskCard(task)),
      ],
    );
  }

  Widget _buildTaskCard(models.TeacherTask task) {
    return GestureDetector(
      onTap: () => context.push('/teacher/homework'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: StudentColors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Text(task.icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: const TextStyle(
                      fontFamily: AppFonts.heading,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${task.class_} • ${task.count} submissions',
                    style: const TextStyle(
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
                'Due: ${task.dueDate}',
                style: const TextStyle(
                  color: StudentColors.warning,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _initials(String name) {
    final i = name
        .trim()
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0] : '')
        .join()
        .toUpperCase();
    return Center(
      child: Text(
        i,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}
