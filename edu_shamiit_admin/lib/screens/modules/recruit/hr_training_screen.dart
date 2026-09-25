import 'package:flutter/material.dart';
import 'package:edu_shamiit_admin/widgets/hr_management_tab_header.dart';
import 'package:edu_shamiit_core/services/api_service.dart';
import 'package:edu_shamiit_admin/services/hr_lookup_helper.dart';

import 'widgets/create_training_dialog.dart';
import 'widgets/training_detail_drawer.dart';
import 'widgets/assign_employees_dialog.dart';
import 'widgets/add_session_dialog.dart';
import 'widgets/certificates_dialog.dart';
import 'widgets/training_calendar_dialog.dart';
import 'widgets/skill_gaps_dialog.dart';
import 'widgets/training_reports_dialog.dart';
import 'widgets/training_leaderboard_dialog.dart';
import 'widgets/learning_paths_dialog.dart';
import 'widgets/training_activity_log_dialog.dart';

class HRTrainingScreen extends StatefulWidget {
  const HRTrainingScreen({super.key});

  @override
  State<HRTrainingScreen> createState() => _HRTrainingScreenState();
}

class _HRTrainingScreenState extends State<HRTrainingScreen> {
  final ApiService _api = ApiService();

  bool _isLoading = false;
  String _selectedTab = 'all';
  String _searchQuery = '';
  int _currentPage = 1;
  int _pageSize = 5;
  int _totalPrograms = 28;
  int _totalPages = 6;

  // Filters
  String _filterCategory = 'All';
  String _filterDepartment = 'All';
  String _filterMode = 'All';
  List<String> _categoryFilterOptions = ['All', ...HRLookupHelper.instance.getCachedLabels('TRAINING_CATEGORY')];
  List<String> _departmentFilterOptions = ['All', ...HRLookupHelper.instance.getCachedLabels('DEPARTMENT')];
  List<String> _modeFilterOptions = ['All', ...HRLookupHelper.instance.getCachedLabels('TRAINING_MODE')];

  // Chart interactivity state
  int? _hoveredTrendIndex;
  String _trendMetricMode = 'rate'; // 'rate', 'count', 'cumulative'

  // Data state
  Map<String, dynamic> _kpis = {
    'total_trainings': 28,
    'completed_trainings': 22,
    'in_progress_trainings': 5,
    'total_participants': 186,
    'completion_rate': 82.0,
    'training_hours': 548,
  };
  List<dynamic> _learningPaths = [
    {
      'title': 'Leadership Development Program',
      'subtitle': 'For teaching & non-teaching staff',
      'icon': Icons.groups_outlined,
      'color': 0xFF6366F1,
      'progress': 0.75,
      'enrolled': 15,
      'capacity': 20,
    },
    {
      'title': 'Digital Skills & Technology',
      'subtitle': 'Tools for modern education',
      'icon': Icons.laptop_chromebook_outlined,
      'color': 0xFF0284C7,
      'progress': 0.60,
      'enrolled': 12,
      'capacity': 20,
    },
    {
      'title': 'Teaching Excellence',
      'subtitle': 'Better teaching, better learning',
      'icon': Icons.lightbulb_outline,
      'color': 0xFF10B981,
      'progress': 0.90,
      'enrolled': 18,
      'capacity': 20,
    },
    {
      'title': 'Soft Skills & Communication',
      'subtitle': 'Build better relationships',
      'icon': Icons.chat_bubble_outline,
      'color': 0xFFEC4899,
      'progress': 0.45,
      'enrolled': 9,
      'capacity': 20,
    },
    {
      'title': 'Compliance & Safety',
      'subtitle': 'Policies, safety & regulations',
      'icon': Icons.verified_user_outlined,
      'color': 0xFFF59E0B,
      'progress': 0.30,
      'enrolled': 6,
      'capacity': 20,
    },
  ];
  List<dynamic> _monthlyTrend = [
    {'month': 'Jan', 'completed': 20, 'in_progress': 12},
    {'month': 'Feb', 'completed': 35, 'in_progress': 18},
    {'month': 'Mar', 'completed': 45, 'in_progress': 22},
    {'month': 'Apr', 'completed': 48, 'in_progress': 25},
    {'month': 'May', 'completed': 52, 'in_progress': 28},
    {'month': 'Jun', 'completed': 58, 'in_progress': 32},
    {'month': 'Jul', 'completed': 64, 'in_progress': 36},
    {'month': 'Aug', 'completed': 68, 'in_progress': 42},
    {'month': 'Sep', 'completed': 74, 'in_progress': 46},
    {'month': 'Oct', 'completed': 78, 'in_progress': 48},
    {'month': 'Nov', 'completed': 82, 'in_progress': 50},
    {'month': 'Dec', 'completed': 88, 'in_progress': 52},
  ];
  List<dynamic> _upcomingSessions = [
    {
      'day': '16',
      'month': 'May',
      'title': 'Advanced Excel for Data Analysis',
      'trainer': 'Rohan Mehta',
      'time': '10:00 AM - 12:00 PM',
      'status': 'Scheduled',
    },
    {
      'day': '17',
      'month': 'May',
      'title': 'Classroom Management Strategies',
      'trainer': 'Priya Singh',
      'time': '02:00 PM - 04:00 PM',
      'status': 'Scheduled',
    },
    {
      'day': '19',
      'month': 'May',
      'title': 'Effective Communication Skills',
      'trainer': 'Amit Sharma',
      'time': '11:00 AM - 01:00 PM',
      'status': 'Scheduled',
    },
    {
      'day': '21',
      'month': 'May',
      'title': 'Cybersecurity Awareness',
      'trainer': 'Neha Gupta',
      'time': '03:00 PM - 05:00 PM',
      'status': 'Scheduled',
    },
    {
      'day': '24',
      'month': 'May',
      'title': 'Smart Classroom Tools',
      'trainer': 'Vikram Patel',
      'time': '10:00 AM - 12:00 PM',
      'status': 'Upcoming',
    },
  ];
  DateTime _calendarMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  List<dynamic> _allCalendarSessions = [];
  List<dynamic> _topEmployees = [
    {'name': 'Ananya Sharma', 'code': 'Emp1267', 'department': 'Academics', 'completion_rate': 100},
    {'name': 'Rahul Verma', 'code': 'Emp1268', 'department': 'Academics', 'completion_rate': 95},
    {'name': 'Neha Singh', 'code': 'Emp1269', 'department': 'Administration', 'completion_rate': 92},
    {'name': 'Vikram Patel', 'code': 'Emp1270', 'department': 'Finance', 'completion_rate': 88},
    {'name': 'Pooja Mehta', 'code': 'Emp1271', 'department': 'Transport', 'completion_rate': 85},
  ];
  List<dynamic> _recentActivities = [
    {'text': 'Ananya Sharma completed "Advanced Excel"', 'time': '2 hours ago', 'icon': Icons.check_circle_outline},
    {'text': 'Rahul Verma enrolled in "Digital Marketing Basics"', 'time': '4 hours ago', 'icon': Icons.assignment_ind_outlined},
    {'text': 'Neha Singh attended "Classroom Management"', 'time': '1 day ago', 'icon': Icons.how_to_reg_outlined},
    {'text': 'Vikram Patel completed "Cybersecurity Awareness"', 'time': '1 day ago', 'icon': Icons.check_circle_outline},
    {'text': 'Pooja Mehta joined "Leadership Development Program"', 'time': '2 days ago', 'icon': Icons.group_add_outlined},
    {'text': 'Amit Kumar assigned to "Smart Classroom Tools"', 'time': '3 days ago', 'icon': Icons.person_add_alt_outlined},
  ];
  List<dynamic> _programs = [
    {
      'id': '1',
      'title': 'Advanced Excel',
      'type': 'Online',
      'department': 'Administration',
      'duration_display': '2 Hours',
      'enrolled_count': 18,
      'status': 'Completed',
    },
    {
      'id': '2',
      'title': 'Child Psychology',
      'type': 'Workshop',
      'department': 'Teaching',
      'duration_display': '1 Day',
      'enrolled_count': 24,
      'status': 'In Progress',
    },
    {
      'id': '3',
      'title': 'Digital Marketing Basics',
      'type': 'Online',
      'department': 'Administration',
      'duration_display': '3 Hours',
      'enrolled_count': 12,
      'status': 'Completed',
    },
    {
      'id': '4',
      'title': 'Classroom Management',
      'type': 'Workshop',
      'department': 'Teaching',
      'duration_display': '1 Day',
      'enrolled_count': 20,
      'status': 'Scheduled',
    },
    {
      'id': '5',
      'title': 'Cybersecurity Awareness',
      'type': 'Online',
      'department': 'IT & Support',
      'duration_display': '2 Hours',
      'enrolled_count': 15,
      'status': 'Upcoming',
    },
  ];
  Map<String, dynamic> _tabCounts = {
    'all': 28,
    'completed': 22,
    'in_progress': 5,
    'upcoming': 1,
  };

  @override
  void initState() {
    super.initState();
    HRLookupHelper.instance.addListener(_onLookupsChanged);
    _loadAllData();
  }

  void _onLookupsChanged() {
    if (mounted) {
      _loadFilterLookups(true);
    }
  }

  @override
  void dispose() {
    HRLookupHelper.instance.removeListener(_onLookupsChanged);
    super.dispose();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchDashboardStats(),
      _fetchPrograms(),
      _fetchCalendarSessions(),
      _loadFilterLookups(true),
    ]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _fetchCalendarSessions() async {
    try {
      final res = await _api.get('/training/sessions', useCache: false);
      if (res['success'] == true && mounted) {
        setState(() {
          _allCalendarSessions = (res['data'] as List<dynamic>?) ?? [];
        });
      }
    } catch (_) {}
  }

  Future<void> _loadFilterLookups([bool forceRefresh = true]) async {
    final cats = await HRLookupHelper.instance.getLookupLabels('TRAINING_CATEGORY', forceRefresh: forceRefresh);
    final depts = await HRLookupHelper.instance.getLookupLabels('DEPARTMENT', forceRefresh: forceRefresh);
    final modes = await HRLookupHelper.instance.getLookupLabels('TRAINING_MODE', forceRefresh: forceRefresh);
    if (mounted) {
      setState(() {
        _categoryFilterOptions = ['All', ...cats];
        _departmentFilterOptions = ['All', ...depts];
        _modeFilterOptions = ['All', ...modes];
      });
    }
  }

  Future<void> _fetchDashboardStats() async {
    try {
      final res = await _api.get('/training/stats', useCache: false);
      if (mounted) {
        setState(() {
          _kpis = res['kpis'] ?? {};
          _learningPaths = res['learning_paths'] ?? [];
          _monthlyTrend = res['monthly_trend'] ?? [];
          _upcomingSessions = res['upcoming_sessions'] ?? [];
          _topEmployees = res['top_employees'] ?? [];
          _recentActivities = res['recent_activities'] ?? [];
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchPrograms() async {
    try {
      final params = <String>[
        'tab=$_selectedTab',
        'page=$_currentPage',
        'page_size=$_pageSize',
      ];
      if (_searchQuery.isNotEmpty) params.add('search=$_searchQuery');
      if (_filterCategory != 'All') params.add('category_name=$_filterCategory');
      if (_filterDepartment != 'All') params.add('department=$_filterDepartment');
      if (_filterMode != 'All') params.add('mode=$_filterMode');

      final qStr = '?${params.join('&')}';
      final res = await _api.get('/training/programs$qStr', useCache: false);
      if (mounted) {
        setState(() {
          _programs = res['data'] ?? [];
          _totalPrograms = res['total'] ?? _programs.length;
          _totalPages = res['total_pages'] ?? 1;
          _tabCounts = res['tab_counts'] ?? {};
        });
      }
    } catch (_) {}
  }

  void _openCreateTrainingDialog() {
    showDialog(
      context: context,
      builder: (_) => CreateTrainingDialog(
        onTrainingCreated: _loadAllData,
      ),
    );
  }

  void _openTrainingDetail(String programId) {
    showDialog(
      context: context,
      builder: (_) => TrainingDetailDrawer(
        programId: programId,
        onProgramUpdated: _loadAllData,
      ),
    );
  }

  void _openCalendarDialog() {
    showDialog(
      context: context,
      builder: (_) => TrainingCalendarDialog(
        onSessionChanged: _loadAllData,
      ),
    );
  }

  void _onCalendarDayTapped(int dayNum, List<dynamic> dateSessions, DateTime selectedDate) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final dateFormatted = '$dayNum ${monthNames[selectedDate.month - 1]} ${selectedDate.year}';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.calendar_today_rounded, color: Color(0xFF4F46E5), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateFormatted,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Outfit'),
                  ),
                  Text(
                    dateSessions.isEmpty
                        ? 'No sessions scheduled'
                        : '${dateSessions.length} session${dateSessions.length > 1 ? 's' : ''} scheduled',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: dateSessions.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.event_busy_rounded, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        'No training sessions on this date',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'You can view all upcoming programs in the full calendar or schedule a new training program.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                )
              : ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: dateSessions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final s = dateSessions[i];
                      final title = s['session_title'] ?? s['title'] ?? 'Training Session';
                      final progTitle = s['program_title'] ?? '';
                      final trainer = s['trainer_name'] ?? s['trainer'] ?? 'Faculty Lead';
                      final startTime = s['start_time'] ?? '';
                      final endTime = s['end_time'] ?? '';
                      final time = (startTime.isNotEmpty && endTime.isNotEmpty)
                          ? '$startTime - $endTime'
                          : (s['time'] ?? 'Time not set');
                      final mode = s['mode'] ?? 'Offline';
                      final location = s['location_or_link'] ?? '';
                      final stat = (s['status'] ?? 'Scheduled').toString();
                      final programId = s['program_id']?.toString();

                      Color statColor = const Color(0xFF4F46E5);
                      if (stat.toUpperCase() == 'COMPLETED') statColor = const Color(0xFF10B981);
                      if (stat.toUpperCase() == 'IN_PROGRESS') statColor = const Color(0xFF0284C7);
                      if (stat.toUpperCase() == 'UPCOMING' || stat.toUpperCase() == 'SCHEDULED') statColor = const Color(0xFFF59E0B);

                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: statColor.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: statColor.withValues(alpha: 0.4)),
                                  ),
                                  child: Text(
                                    stat.replaceAll('_', ' '),
                                    style: TextStyle(color: statColor, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            if (progTitle.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                progTitle,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF4F46E5), fontWeight: FontWeight.w500),
                              ),
                            ],
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 12,
                              runSpacing: 4,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.access_time_rounded, size: 12, color: Colors.grey.shade500),
                                    const SizedBox(width: 4),
                                    Text(time, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.person_outline_rounded, size: 12, color: Colors.grey.shade500),
                                    const SizedBox(width: 4),
                                    Text(trainer, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                  ],
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.videocam_outlined, size: 12, color: Colors.grey.shade500),
                                    const SizedBox(width: 4),
                                    Text(mode, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                  ],
                                ),
                                if (location.isNotEmpty)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.location_on_outlined, size: 12, color: Colors.grey.shade500),
                                      const SizedBox(width: 4),
                                      Text(location, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                                    ],
                                  ),
                              ],
                            ),
                            if (programId != null && programId.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () {
                                    Navigator.of(ctx).pop();
                                    _openTrainingDetail(programId);
                                  },
                                  icon: const Icon(Icons.arrow_outward_rounded, size: 13),
                                  label: const Text('View Program Details', style: TextStyle(fontSize: 11)),
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.of(ctx).pop();
              _openCalendarDialog();
            },
            icon: const Icon(Icons.calendar_month_outlined, size: 16),
            label: const Text('Full Calendar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _openReportsDialog() {
    showDialog(
      context: context,
      builder: (_) => const TrainingReportsDialog(),
    );
  }

  void _openCertificatesDialog() {
    showDialog(
      context: context,
      builder: (_) => CertificatesDialog(
        onCertificateChanged: _loadAllData,
      ),
    );
  }

  void _openSkillGapsDialog() {
    showDialog(
      context: context,
      builder: (_) => SkillGapsDialog(
        onGapsChanged: _loadAllData,
      ),
    );
  }

  void _openLeaderboardDialog() {
    showDialog(
      context: context,
      builder: (_) => const TrainingLeaderboardDialog(),
    );
  }

  void _openLearningPathsDialog() {
    showDialog(
      context: context,
      builder: (_) => const LearningPathsDialog(),
    );
  }

  void _openActivityLogDialog() {
    showDialog(
      context: context,
      builder: (_) => const TrainingActivityLogDialog(),
    );
  }

  Future<void> _changeProgramStatus(String programId, String newStatus) async {
    try {
      final res = await _api.patch('/training/programs/$programId/status', {'status': newStatus});
      if (res['success'] == true) {
        _loadAllData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Status updated to $newStatus!'), backgroundColor: const Color(0xFF10B981)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating status: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openStatusChangeDialog(String programId, String currentStatus, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Change Status: $title'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['DRAFT', 'SCHEDULED', 'UPCOMING', 'IN_PROGRESS', 'COMPLETED', 'ARCHIVED', 'CANCELLED'].map((s) {
            final isCurrent = s == currentStatus.toUpperCase();
            Color col = const Color(0xFF4F46E5);
            if (s == 'COMPLETED') col = const Color(0xFF10B981);
            if (s == 'IN_PROGRESS') col = const Color(0xFF0284C7);
            if (s == 'UPCOMING' || s == 'SCHEDULED') col = const Color(0xFFF59E0B);
            if (s == 'CANCELLED' || s == 'ARCHIVED') col = Colors.grey;

            return ListTile(
              leading: Container(width: 10, height: 10, decoration: BoxDecoration(color: col, shape: BoxShape.circle)),
              title: Text(s.replaceAll('_', ' '), style: TextStyle(fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal)),
              trailing: isCurrent ? const Icon(Icons.check, color: Color(0xFF10B981)) : null,
              onTap: () {
                Navigator.pop(ctx);
                _changeProgramStatus(programId, s);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    );
  }

  void _confirmDeleteProgram(String programId, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Training Program'),
        content: Text('Are you sure you want to permanently delete "$title"? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final res = await _api.delete('/training/programs/$programId');
                if (res['success'] == true) {
                  _loadAllData();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Program "$title" deleted successfully.'), backgroundColor: const Color(0xFF10B981)),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting program: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090D1A) : const Color(0xFFF8FAFC),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Unified HR Management Header (Active Tab: Training)
          HRManagementHeader(
            activeTab: HRTab.training,
            title: 'Training & Learning',
            subtitle: 'Facilitate teacher development, professional upskilling, and compliance certifications.',
            icon: Icons.school_rounded,
            onRefresh: _loadAllData,
            isRefreshing: _isLoading,
            actions: [
              OutlinedButton.icon(
                onPressed: _openCalendarDialog,
                icon: Icon(Icons.calendar_month_outlined, size: 16, color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5)),
                label: Text(
                  'Training Calendar',
                  style: TextStyle(
                    color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Inter',
                    fontSize: 13,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _openReportsDialog,
                icon: Icon(Icons.analytics_outlined, size: 16, color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5)),
                label: Text(
                  'Reports',
                  style: TextStyle(
                    color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Inter',
                    fontSize: 13,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _openCreateTrainingDialog,
                icon: const Icon(Icons.add, size: 16, color: Colors.white),
                label: const Text(
                  'Create Training Program',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontFamily: 'Inter', fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              PopupMenuButton<String>(
                icon: Container(
                  height: 38,
                  width: 38,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                  ),
                  child: Icon(Icons.more_vert_rounded, size: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
                onSelected: (val) {
                  if (val == 'certs') _openCertificatesDialog();
                  if (val == 'gaps') _openSkillGapsDialog();
                  if (val == 'reports') _openReportsDialog();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'certs', child: Row(children: [Icon(Icons.workspace_premium_outlined, size: 16), SizedBox(width: 8), Text('Certificates Registry')])),
                  PopupMenuItem(value: 'gaps', child: Row(children: [Icon(Icons.psychology_alt_outlined, size: 16), SizedBox(width: 8), Text('Skill Gaps & Training Needs')])),
                  PopupMenuItem(value: 'reports', child: Row(children: [Icon(Icons.download_rounded, size: 16), SizedBox(width: 8), Text('Export All Data (CSV)')])),
                ],
              ),
            ],
          ),

          // 2. Main Scrollable Content
          Expanded(
            child: Stack(
              children: [
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        // 6 KPI Cards
                        _buildKpiRow(isDark),
                        const SizedBox(height: 24),

                        // Middle Section: Learning Paths + Trend Chart + Upcoming Sessions
                        _buildMiddleSection(isDark),
                        const SizedBox(height: 24),

                        // Lower Section: Programs Table + Top Employees
                        _buildProgramsAndTopEmployees(isDark),
                        const SizedBox(height: 24),

                        // Bottom Row: Recent Activity + Mini Calendar + Banner
                        _buildBottomRow(isDark),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                  if (_isLoading)
                    const Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: LinearProgressIndicator(
                        minHeight: 2.5,
                        backgroundColor: Colors.transparent,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }



  // =========================================================================
  // 6 KPI CARDS
  // =========================================================================

  Widget _buildKpiRow(bool isDark) {
    final total = _kpis['total_programs'] ?? 0;
    final completed = _kpis['completed_programs'] ?? 0;
    final inProg = _kpis['in_progress_programs'] ?? 0;
    final part = _kpis['total_participants'] ?? 0;
    final compRate = _kpis['avg_completion_rate'] ?? 0.0;
    final hours = _kpis['training_hours'] ?? 0;

    final totalTrend = _kpis['total_programs_trend']?.toString() ?? '0% vs last month';
    final completedTrend = _kpis['completed_programs_trend']?.toString() ?? '0% vs last month';
    final inProgTrend = _kpis['in_progress_programs_trend']?.toString() ?? '0% vs last month';
    final partTrend = _kpis['total_participants_trend']?.toString() ?? '0% vs last month';
    final compRateTrend = _kpis['avg_completion_rate_trend']?.toString() ?? '0% vs last month';
    final hoursTrend = _kpis['training_hours_trend']?.toString() ?? '0% vs last month';

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final isNarrow = constraints.maxWidth < 1000;
        final cardWidth = isNarrow ? (constraints.maxWidth - 16) / 2 : (constraints.maxWidth - 5 * 12) / 6;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildKpiCard('Total Trainings', '$total', totalTrend, Icons.people_outline, const Color(0xFF4F46E5), cardWidth, isDark),
            _buildKpiCard('Completed Trainings', '$completed', completedTrend, Icons.task_alt_outlined, const Color(0xFF0284C7), cardWidth, isDark),
            _buildKpiCard('In Progress', '$inProg', inProgTrend, Icons.access_time_rounded, const Color(0xFFEC4899), cardWidth, isDark),
            _buildKpiCard('Total Participants', '$part', partTrend, Icons.groups_outlined, const Color(0xFF10B981), cardWidth, isDark),
            _buildKpiCard('Avg. Training Completion', '${compRate.toStringAsFixed(0)}%', compRateTrend, Icons.star_outline_rounded, const Color(0xFFF59E0B), cardWidth, isDark),
            _buildKpiCard('Training Hours', '$hours', hoursTrend, Icons.hourglass_empty_rounded, const Color(0xFF7C3AED), cardWidth, isDark),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard(String title, String value, String trend, IconData icon, Color color, double width, bool isDark) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13182C) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
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
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
              color: isDark ? Colors.white : const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                trend,
                style: const TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // MIDDLE SECTION: LEARNING PATHS + TREND LINE CHART + UPCOMING SESSIONS
  // =========================================================================

  Widget _buildMiddleSection(bool isDark) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final isWide = constraints.maxWidth >= 1280;
        if (!isWide) {
          final isTablet = constraints.maxWidth >= 768;
          return Column(
            children: [
              _buildTrendChartCard(isDark),
              const SizedBox(height: 16),
              if (isTablet)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildLearningPathsCard(isDark)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildUpcomingSessionsCard(isDark)),
                  ],
                )
              else ...[
                _buildLearningPathsCard(isDark),
                const SizedBox(height: 16),
                _buildUpcomingSessionsCard(isDark),
              ],
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: _buildLearningPathsCard(isDark)),
            const SizedBox(width: 16),
            Expanded(flex: 4, child: _buildTrendChartCard(isDark)),
            const SizedBox(width: 16),
            Expanded(flex: 3, child: _buildUpcomingSessionsCard(isDark)),
          ],
        );
      },
    );
  }

  Widget _buildLearningPathsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13182C) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Learning Paths', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Outfit')),
                    const SizedBox(height: 2),
                    Text('Structured learning journeys for professional growth.', style: TextStyle(fontSize: 11, color: Colors.grey.shade600), overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _openLearningPathsDialog,
                child: const Row(children: [Text('View All', style: TextStyle(fontSize: 12)), Icon(Icons.arrow_forward, size: 14)]),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 14),
          ..._learningPaths.map((lp) => _buildLearningPathItem(lp, isDark)),
        ],
      ),
    );
  }

  Widget _buildLearningPathItem(Map<String, dynamic> lp, bool isDark) {
    final title = lp['title'] ?? 'Program';
    final subtitle = lp['subtitle'] ?? '';
    final pct = (lp['progress_percentage'] ?? 0) as int;
    final done = lp['completed_courses'] ?? 0;
    final total = lp['total_courses'] ?? 0;
    final hexStr = lp['color_hex'] ?? '#4F46E5';
    final color = Color(int.parse(hexStr.replaceFirst('#', '0xFF')));

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: LayoutBuilder(
        builder: (ctx, constraints) {
          final isCompact = constraints.maxWidth < 220;
          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(Icons.school_outlined, color: color, size: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct / 100,
                          minHeight: 5,
                          backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$done/$total',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ],
            );
          }

          return Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.school_outlined, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 44,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: pct / 100,
                    minHeight: 5,
                    backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '$done/$total',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Colors.grey.shade600),
              ),
              const SizedBox(width: 2),
              Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade400),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTrendChartCard(bool isDark) {
    final activeData = _hoveredTrendIndex != null && _hoveredTrendIndex! >= 0 && _hoveredTrendIndex! < _monthlyTrend.length
        ? _monthlyTrend[_hoveredTrendIndex!]
        : null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13182C) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (ctx, headerConstraints) {
              final isCompact = headerConstraints.maxWidth < 620;

              final titleWidget = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      const Text('Training Overview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Outfit')),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sync_rounded, size: 10, color: Color(0xFF10B981)),
                            SizedBox(width: 3),
                            Text('LIVE DB', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _trendMetricMode == 'count'
                        ? 'Program volume & active participation by month'
                        : (_trendMetricMode == 'cumulative'
                            ? 'Cumulative annual training progression (YTD)'
                            : 'Monthly completion rate and in-progress ratio'),
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              );

              final controlsWidget = Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Mode Toggle
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildModeChip('Rate (%)', 'rate', isDark),
                        _buildModeChip('Counts', 'count', isDark),
                        _buildModeChip('YTD', 'cumulative', isDark),
                      ],
                    ),
                  ),
                  _buildLegendDot('Completed', const Color(0xFF4F46E5)),
                  _buildLegendDot('In Progress', const Color(0xFF0284C7)),
                ],
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleWidget,
                    const SizedBox(height: 10),
                    controlsWidget,
                  ],
                );
              }

              return Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.start,
                spacing: 12,
                runSpacing: 10,
                children: [
                  titleWidget,
                  controlsWidget,
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Interactive Hover Details Bar
          if (activeData != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.3)),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_month_rounded, size: 16, color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5)),
                      const SizedBox(width: 6),
                      Text(
                        '${activeData['month']} 2026:',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                  Text(
                    'Completed: ${_trendMetricMode == 'count' ? activeData['completed_programs'] ?? 0 : '${(activeData['completed_rate'] ?? 0).toStringAsFixed(1)}%'}',
                    style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  Text(
                    'In Progress: ${_trendMetricMode == 'count' ? activeData['in_progress_programs'] ?? 0 : '${(activeData['in_progress_rate'] ?? 0).toStringAsFixed(1)}%'}',
                    style: const TextStyle(color: Color(0xFF0284C7), fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  Text(
                    'Total Programs: ${activeData['total_programs'] ?? 0} | Staff: ${activeData['total_enrolled'] ?? 0}',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),

          // Canvas Graph
          SizedBox(
            height: 220,
            child: LayoutBuilder(
              builder: (ctx, constraints) {
                return MouseRegion(
                  onHover: (event) {
                    final n = _monthlyTrend.length;
                    if (n < 2) return;
                    const leftMargin = 38.0;
                    const rightMargin = 16.0;
                    final plotW = constraints.maxWidth - leftMargin - rightMargin;
                    final stepX = plotW / (n - 1);
                    final localX = event.localPosition.dx - leftMargin;
                    final idx = (localX / stepX).round().clamp(0, n - 1);
                    if (_hoveredTrendIndex != idx) {
                      setState(() => _hoveredTrendIndex = idx);
                    }
                  },
                  onExit: (_) {
                    if (_hoveredTrendIndex != null) {
                      setState(() => _hoveredTrendIndex = null);
                    }
                  },
                  child: CustomPaint(
                    size: Size(constraints.maxWidth, 220),
                    painter: _TrendChartPainter(
                      _monthlyTrend,
                      isDark,
                      hoveredIndex: _hoveredTrendIndex,
                      mode: _trendMetricMode,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeChip(String label, String modeVal, bool isDark) {
    final isSelected = _trendMetricMode == modeVal;
    return InkWell(
      onTap: () => setState(() => _trendMetricMode = modeVal),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4F46E5) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : (isDark ? Colors.white70 : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildLegendDot(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildUpcomingSessionsCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13182C) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text('Upcoming Training Sessions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Outfit'), overflow: TextOverflow.ellipsis),
              ),
              TextButton(
                onPressed: _openCalendarDialog,
                child: const Row(children: [Text('View All', style: TextStyle(fontSize: 12)), Icon(Icons.arrow_forward, size: 14)]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 10),
          if (_upcomingSessions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.event_available_outlined, size: 36, color: Colors.grey.shade400),
                    const SizedBox(height: 8),
                    Text('No upcoming sessions scheduled', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                  ],
                ),
              ),
            )
          else
            ..._upcomingSessions.map((s) => _buildUpcomingSessionTile(s, isDark)),
        ],
      ),
    );
  }

  Widget _buildUpcomingSessionTile(Map<String, dynamic> s, bool isDark) {
    final title = s['session_title'] ?? 'Workshop';
    final trainer = s['trainer_name'] ?? 'Faculty Lead';
    final dateStr = (s['session_date'] ?? DateTime.now().toIso8601String().split('T').first).toString();
    final parsedDate = DateTime.tryParse(dateStr.split('T').first) ?? DateTime.now();
    final day = parsedDate.day.toString().padLeft(2, '0');
    const months = ['JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN', 'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC'];
    final month = months[parsedDate.month - 1];
    final time = '${s['start_time'] ?? '10:00'} - ${s['end_time'] ?? '12:00'}';
    final stat = (s['status'] ?? 'Scheduled').toString();

    final isScheduled = stat.toUpperCase() == 'SCHEDULED';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                Text(day, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF4F46E5))),
                Text(month, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('By: $trainer', style: TextStyle(fontSize: 11, color: Colors.grey.shade600), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(time, style: TextStyle(fontSize: 10, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isScheduled ? const Color(0xFF4F46E5).withValues(alpha: 0.1) : const Color(0xFFF59E0B).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: isScheduled ? const Color(0xFF4F46E5).withValues(alpha: 0.3) : const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                ),
                child: Text(
                  stat,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isScheduled ? const Color(0xFF4F46E5) : const Color(0xFFF59E0B),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // LOWER SECTION: TRAINING PROGRAMS TABLE + TOP PERFORMING EMPLOYEES
  // =========================================================================

  Widget _buildProgramsAndTopEmployees(bool isDark) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final isWide = constraints.maxWidth >= 1050;
        if (!isWide) {
          return Column(
            children: [
              _buildProgramsTableCard(isDark),
              const SizedBox(height: 16),
              _buildTopEmployeesCard(isDark),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 7, child: _buildProgramsTableCard(isDark)),
            const SizedBox(width: 16),
            Expanded(flex: 3, child: _buildTopEmployeesCard(isDark)),
          ],
        );
      },
    );
  }

  Widget _buildProgramsTableCard(bool isDark) {
    final allCount = _tabCounts['all_count'] ?? _totalPrograms;
    final compCount = _tabCounts['completed_count'] ?? 0;
    final inProgCount = _tabCounts['in_progress_count'] ?? 0;
    final upCount = _tabCounts['upcoming_count'] ?? 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13182C) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Tabs & Search
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              const Text(
                'Training Programs & Courses',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Outfit'),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 220,
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search training programs...',
                        prefixIcon: Icon(Icons.search, size: 18),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) {
                        _searchQuery = v.trim();
                        _currentPage = 1;
                        _fetchPrograms();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () {
                      _openFilterModal();
                    },
                    icon: const Icon(Icons.tune_rounded, size: 16),
                    label: const Text('Filters'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tab Selector Bar (Scrollable for smaller screens)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterTab('all', 'All ($allCount)'),
                const SizedBox(width: 8),
                _buildFilterTab('completed', 'Completed ($compCount)'),
                const SizedBox(width: 8),
                _buildFilterTab('in_progress', 'In Progress ($inProgCount)'),
                const SizedBox(width: 8),
                _buildFilterTab('upcoming', 'Upcoming ($upCount)'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),

          // Primary Table (Flexible & responsive for all screen sizes)
          LayoutBuilder(
            builder: (ctx, tableConstraints) {
              final availableWidth = tableConstraints.maxWidth;
              const minTableWidth = 860.0;
              final tableWidth = availableWidth > minTableWidth ? availableWidth : minTableWidth;

              // Fixed column widths:
              const typeWidth = 75.0;
              const durationWidth = 80.0;
              const participantsWidth = 85.0;
              const statusWidth = 100.0;
              const actionsWidth = 92.0;
              const colSpacing = 16.0;
              const horizMargin = 12.0;

              // Total non-flexible width (5 fixed columns + 2 margins + 6 column spacings)
              const fixedWidth = typeWidth + durationWidth + participantsWidth + statusWidth + actionsWidth + (horizMargin * 2) + (colSpacing * 6);
              final flexWidth = tableWidth - fixedWidth;

              // Proportional distribution between Course Name (60%) and Department (40%)
              final courseNameWidth = (flexWidth * 0.60).clamp(240.0, 1000.0);
              final deptWidth = (flexWidth - courseNameWidth).clamp(120.0, 600.0);

              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: tableWidth),
                  child: DataTable(
                    columnSpacing: colSpacing,
                    horizontalMargin: horizMargin,
                    headingRowHeight: 40,
                    dataRowMinHeight: 52,
                    dataRowMaxHeight: 60,
                    columns: [
                      DataColumn(label: SizedBox(width: courseNameWidth, child: const Text('Course Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                      const DataColumn(label: SizedBox(width: typeWidth, child: Text('Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                      DataColumn(label: SizedBox(width: deptWidth, child: const Text('Department', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                      const DataColumn(label: SizedBox(width: durationWidth, child: Text('Duration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                      const DataColumn(label: SizedBox(width: participantsWidth, child: Text('Participants', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                      const DataColumn(label: SizedBox(width: statusWidth, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                      const DataColumn(label: SizedBox(width: actionsWidth, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                    ],
                    rows: _programs.map((p) {
                      final id = p['id'].toString();
                      final title = p['title'] ?? 'Course';
                      final code = p['program_code'] ?? 'TRN';
                      final type = p['mode'] ?? 'Online';
                      final dept = p['target_audience'] ?? 'Administration';
                      final duration = p['duration_display'] ?? '2 Hours';
                      final enrolled = p['enrolled_count'] ?? 0;
                      final stat = (p['status'] ?? 'COMPLETED').toString().toUpperCase();

                      Color badgeColor = const Color(0xFF10B981);
                      Color badgeBg = const Color(0xFF10B981).withValues(alpha: 0.1);
                      if (stat == 'IN_PROGRESS') {
                        badgeColor = const Color(0xFF0284C7);
                        badgeBg = const Color(0xFF0284C7).withValues(alpha: 0.1);
                      } else if (stat == 'SCHEDULED') {
                        badgeColor = const Color(0xFF7C3AED);
                        badgeBg = const Color(0xFF7C3AED).withValues(alpha: 0.1);
                      } else if (stat == 'UPCOMING') {
                        badgeColor = const Color(0xFFF59E0B);
                        badgeBg = const Color(0xFFF59E0B).withValues(alpha: 0.1);
                      }

                      return DataRow(
                        cells: [
                          DataCell(
                            SizedBox(
                              width: courseNameWidth,
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.menu_book_rounded, size: 16, color: Color(0xFF4F46E5)),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          title,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          code,
                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          DataCell(SizedBox(width: typeWidth, child: Text(type, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)))),
                          DataCell(SizedBox(width: deptWidth, child: Text(dept, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)))),
                          DataCell(SizedBox(width: durationWidth, child: Text(duration, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)))),
                          DataCell(SizedBox(width: participantsWidth, child: Text('$enrolled', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)))),
                          DataCell(
                            SizedBox(
                              width: statusWidth,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: badgeBg,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    stat.replaceAll('_', ' '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 11),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: actionsWidth,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    width: 36,
                                    height: 36,
                                    child: IconButton(
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(Icons.visibility_outlined, size: 18),
                                      tooltip: 'View Training Details',
                                      onPressed: () => _openTrainingDetail(id),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  SizedBox(
                                    width: 36,
                                    height: 36,
                                    child: PopupMenuButton<String>(
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(Icons.more_vert, size: 18),
                                      onSelected: (val) {
                                      if (val == 'view') {
                                        _openTrainingDetail(id);
                                      } else if (val == 'status') {
                                        _openStatusChangeDialog(id, stat, title);
                                      } else if (val == 'assign') {
                                        showDialog(
                                          context: context,
                                          builder: (_) => AssignEmployeesDialog(
                                            programId: id,
                                            programTitle: title,
                                            onAssigned: _loadAllData,
                                          ),
                                        );
                                      } else if (val == 'session') {
                                        showDialog(
                                          context: context,
                                          builder: (_) => AddSessionDialog(
                                            programId: id,
                                            programTitle: title,
                                            onSessionAdded: _loadAllData,
                                          ),
                                        );
                                      } else if (val == 'delete') {
                                        _confirmDeleteProgram(id, title);
                                      }
                                    },
                                    itemBuilder: (_) => const [
                                      PopupMenuItem(value: 'view', child: Row(children: [Icon(Icons.open_in_new, size: 16), SizedBox(width: 8), Text('Open Drawer')])),
                                      PopupMenuItem(value: 'status', child: Row(children: [Icon(Icons.published_with_changes_rounded, size: 16), SizedBox(width: 8), Text('Change Status')])),
                                      PopupMenuItem(value: 'assign', child: Row(children: [Icon(Icons.person_add, size: 16), SizedBox(width: 8), Text('Assign Employees')])),
                                      PopupMenuItem(value: 'session', child: Row(children: [Icon(Icons.event, size: 16), SizedBox(width: 8), Text('Add Session')])),
                                      PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 16, color: Colors.red), SizedBox(width: 8), Text('Delete Program', style: TextStyle(color: Colors.red))])),
                                    ],
                                  ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              );
            },
          ),

          // Pagination Footer (Responsive Wrap)
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _programs.isEmpty
                        ? 'Showing 0 of $_totalPrograms programs'
                        : 'Showing ${(_currentPage - 1) * _pageSize + 1} to ${((_currentPage - 1) * _pageSize + _programs.length)} of $_totalPrograms programs',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _pageSize,
                        isDense: true,
                        dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B),
                          fontWeight: FontWeight.w600,
                        ),
                        items: const [
                          DropdownMenuItem(value: 5, child: Text('5 per page')),
                          DropdownMenuItem(value: 10, child: Text('10 per page')),
                          DropdownMenuItem(value: 20, child: Text('20 per page')),
                          DropdownMenuItem(value: 50, child: Text('50 per page')),
                          DropdownMenuItem(value: 100, child: Text('100 per page')),
                        ],
                        onChanged: (newSize) {
                          if (newSize != null && newSize != _pageSize) {
                            setState(() {
                              _pageSize = newSize;
                              _currentPage = 1;
                            });
                            _fetchPrograms();
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: _currentPage > 1
                        ? () {
                            setState(() => _currentPage--);
                            _fetchPrograms();
                          }
                        : null,
                  ),
                  ...(() {
                    final startPage = (_currentPage - 2).clamp(1, (_totalPages - 4).clamp(1, _totalPages));
                    final endPage = (startPage + 4).clamp(1, _totalPages);
                    final pages = <int>[];
                    for (var p = startPage; p <= endPage; p++) {
                      pages.add(p);
                    }
                    return pages.map((pNum) {
                      final isCur = pNum == _currentPage;
                      return InkWell(
                        onTap: () {
                          setState(() => _currentPage = pNum);
                          _fetchPrograms();
                        },
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isCur ? const Color(0xFF4F46E5) : Colors.transparent,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: isCur ? const Color(0xFF4F46E5) : (isDark ? const Color(0xFF334155) : Colors.grey.shade300)),
                          ),
                          child: Text(
                            '$pNum',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isCur ? Colors.white : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
                            ),
                          ),
                        ),
                      );
                    });
                  })(),
                  IconButton(
                    icon: const Icon(Icons.chevron_right, size: 18),
                    onPressed: _currentPage < _totalPages
                        ? () {
                            setState(() => _currentPage++);
                            _fetchPrograms();
                          }
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String tabKey, String label) {
    final isSelected = _selectedTab == tabKey;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTab = tabKey;
          _currentPage = 1;
        });
        _fetchPrograms();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4F46E5).withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 12,
            color: isSelected ? const Color(0xFF4F46E5) : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildTopEmployeesCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13182C) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text('Top Performing Employees', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Outfit'), overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _openLeaderboardDialog,
                child: const Row(children: [Text('View All', style: TextStyle(fontSize: 12)), Icon(Icons.arrow_forward, size: 14)]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 12),
          ..._topEmployees.map((emp) => _buildTopEmployeeRow(emp, isDark)),
        ],
      ),
    );
  }

  Widget _buildTopEmployeeRow(Map<String, dynamic> emp, bool isDark) {
    final name = emp['full_name'] ?? 'Staff Member';
    final code = emp['employee_code'] ?? 'Emp--';
    final dept = emp['department'] ?? 'Academics';
    final rate = (emp['completion_rate'] ?? 90) as int;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.1),
            child: Text(
              name.isNotEmpty ? name[0] : 'E',
              style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                Text(code, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
          Text(dept, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$rate%', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 3),
              SizedBox(
                width: 60,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: rate / 100,
                    minHeight: 4,
                    color: const Color(0xFF10B981),
                    backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // BOTTOM ROW: RECENT ACTIVITY + MINI CALENDAR + INVEST BANNER
  // =========================================================================

  Widget _buildBottomRow(bool isDark) {
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final isWide = constraints.maxWidth >= 1100;
        if (!isWide) {
          return Column(
            children: [
              _buildRecentActivityCard(isDark),
              const SizedBox(height: 16),
              _buildMiniCalendarCard(isDark),
              const SizedBox(height: 16),
              _buildInvestBanner(isDark),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 4, child: _buildRecentActivityCard(isDark)),
            const SizedBox(width: 16),
            Expanded(flex: 3, child: _buildMiniCalendarCard(isDark)),
            const SizedBox(width: 16),
            Expanded(flex: 3, child: _buildInvestBanner(isDark)),
          ],
        );
      },
    );
  }

  Widget _buildRecentActivityCard(bool isDark) {
    final acts = _recentActivities.take(6).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13182C) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text('Recent Activity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Outfit'), overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: _openActivityLogDialog,
                child: const Row(children: [Text('View All', style: TextStyle(fontSize: 12)), Icon(Icons.arrow_forward, size: 14)]),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 12),
          // 2 column grid of items
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: acts.map((a) {
              final summary = a['summary'] ?? a['action'] ?? 'Activity recorded';
              const timeAgo = 'Just now';
              return SizedBox(
                width: 190,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.bolt_rounded, size: 14, color: Color(0xFF4F46E5)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(summary, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(timeAgo, style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniCalendarCard(bool isDark) {
    final now = DateTime.now();
    final currentYear = _calendarMonth.year;
    final currentMonth = _calendarMonth.month;
    const monthNames = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];

    final firstDay = DateTime(currentYear, currentMonth, 1);
    final daysInMonth = DateTime(currentYear, currentMonth + 1, 0).day;
    final startOffset = firstDay.weekday % 7; // Sunday = 0
    final totalCells = ((daysInMonth + startOffset) / 7).ceil() * 7;

    // Combine _allCalendarSessions with _upcomingSessions for comprehensive mapping
    final sessionsToMap = _allCalendarSessions.isNotEmpty ? _allCalendarSessions : _upcomingSessions;
    final Map<int, List<dynamic>> daySessions = {};
    final Map<int, Color> highlightedDays = {};

    for (final s in sessionsToMap) {
      final dateStr = s['session_date']?.toString();
      if (dateStr != null) {
        final d = DateTime.tryParse(dateStr.split('T').first);
        if (d != null && d.year == currentYear && d.month == currentMonth) {
          daySessions.putIfAbsent(d.day, () => []).add(s);

          final stat = (s['status'] ?? 'Scheduled').toString().toUpperCase();
          Color c = const Color(0xFF4F46E5);
          if (stat == 'COMPLETED') {
            c = const Color(0xFF10B981);
          } else if (stat == 'IN_PROGRESS') {
            c = const Color(0xFF0284C7);
          } else if (stat == 'UPCOMING') {
            c = const Color(0xFFF59E0B);
          }
          if (!highlightedDays.containsKey(d.day) || stat == 'IN_PROGRESS' || (stat == 'UPCOMING' && highlightedDays[d.day] != const Color(0xFF0284C7))) {
            highlightedDays[d.day] = c;
          }
        }
      }
    }

    final isCurrentMonth = currentYear == now.year && currentMonth == now.month;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13182C) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              InkWell(
                onTap: _openCalendarDialog,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Training Calendar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, fontFamily: 'Outfit')),
                      const SizedBox(width: 5),
                      Icon(Icons.open_in_new_rounded, size: 14, color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5)),
                    ],
                  ),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    tooltip: 'Previous Month',
                    onPressed: () {
                      setState(() {
                        _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month - 1, 1);
                      });
                    },
                  ),
                  Text(
                    '${monthNames[currentMonth - 1]} $currentYear',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                    tooltip: 'Next Month',
                    onPressed: () {
                      setState(() {
                        _calendarMonth = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 1);
                      });
                    },
                  ),
                  if (!isCurrentMonth) ...[
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () {
                        setState(() {
                          _calendarMonth = DateTime(now.year, now.month, 1);
                        });
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('Today', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5))),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // Weekdays header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                .map((d) => Text(d, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade500)))
                .toList(),
          ),
          const SizedBox(height: 8),

          // Month Grid (Dynamic & Interactive)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childAspectRatio: 1.1,
            ),
            itemCount: totalCells,
            itemBuilder: (ctx, idx) {
              final dayNum = idx - startOffset + 1;
              if (dayNum < 1 || dayNum > daysInMonth) {
                return const SizedBox();
              }

              final dotColor = highlightedDays[dayNum];
              final isToday = dayNum == now.day && isCurrentMonth;
              final sessionsOnDay = daySessions[dayNum] ?? [];
              final selectedDate = DateTime(currentYear, currentMonth, dayNum);

              return Tooltip(
                message: sessionsOnDay.isNotEmpty
                    ? '${sessionsOnDay.length} session${sessionsOnDay.length > 1 ? 's' : ''} on ${monthNames[currentMonth - 1]} $dayNum\nClick to view details'
                    : '${monthNames[currentMonth - 1]} $dayNum\nClick to view',
                child: Material(
                  color: Colors.transparent,
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _onCalendarDayTapped(dayNum, sessionsOnDay, selectedDate),
                    hoverColor: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: dotColor != null
                          ? BoxDecoration(
                              color: dotColor.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(color: dotColor.withValues(alpha: 0.5)),
                            )
                          : (isToday
                              ? BoxDecoration(
                                  border: Border.all(color: const Color(0xFF4F46E5), width: 1.5),
                                  shape: BoxShape.circle,
                                )
                              : null),
                      child: Text(
                        '$dayNum',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: (dotColor != null || isToday) ? FontWeight.bold : FontWeight.normal,
                          color: dotColor ?? (isToday ? const Color(0xFF4F46E5) : (isDark ? Colors.white70 : Colors.black87)),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),

          // Legend
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _buildLegendDot('Scheduled', const Color(0xFF4F46E5)),
              _buildLegendDot('In Progress', const Color(0xFF0284C7)),
              _buildLegendDot('Completed', const Color(0xFF10B981)),
              _buildLegendDot('Upcoming', const Color(0xFFF59E0B)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInvestBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E1B4B), const Color(0xFF312E81)]
              : [const Color(0xFFEEF2FF), const Color(0xFFE0E7FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.rocket_launch_rounded, color: Color(0xFF4F46E5), size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Invest in People', style: TextStyle(fontSize: 12, color: Color(0xFF4F46E5), fontWeight: FontWeight.bold)),
                    Text(
                      'Build a Stronger Tomorrow',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Empower your team with the right skills, training and learning opportunities to achieve institutional academic excellence.',
            style: TextStyle(fontSize: 12, height: 1.4, color: isDark ? Colors.white70 : const Color(0xFF334155)),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _openSkillGapsDialog,
            icon: const Icon(Icons.explore_outlined, size: 16, color: Colors.white),
            label: const Text('Explore Learning Resources', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }

  void _openFilterModal() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Filter Training Programs'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _categoryFilterOptions.contains(_filterCategory) ? _filterCategory : 'All',
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Category', border: OutlineInputBorder()),
              items: _categoryFilterOptions.map((c) => DropdownMenuItem(value: c, child: Text(c == 'All' ? 'All Categories' : c))).toList(),
              onChanged: (v) => setState(() => _filterCategory = v ?? 'All'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _departmentFilterOptions.contains(_filterDepartment) ? _filterDepartment : 'All',
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Department', border: OutlineInputBorder()),
              items: _departmentFilterOptions.map((d) => DropdownMenuItem(value: d, child: Text(d == 'All' ? 'All Departments' : d))).toList(),
              onChanged: (v) => setState(() => _filterDepartment = v ?? 'All'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _modeFilterOptions.contains(_filterMode) ? _filterMode : 'All',
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Training Mode', border: OutlineInputBorder()),
              items: _modeFilterOptions.map((m) => DropdownMenuItem(value: m, child: Text(m == 'All' ? 'All Modes' : m))).toList(),
              onChanged: (v) => setState(() => _filterMode = v ?? 'All'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _filterCategory = 'All';
                _filterDepartment = 'All';
                _filterMode = 'All';
              });
              Navigator.pop(ctx);
              _fetchPrograms();
            },
            child: const Text('Reset'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _fetchPrograms();
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
            child: const Text('Apply Filters', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _TrendChartPainter extends CustomPainter {
  final List<dynamic> monthlyData;
  final bool isDark;
  final int? hoveredIndex;
  final String mode;

  _TrendChartPainter(
    this.monthlyData,
    this.isDark, {
    this.hoveredIndex,
    this.mode = 'rate',
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (monthlyData.isEmpty) return;

    const leftMargin = 38.0;
    const rightMargin = 16.0;
    const bottomMargin = 26.0;
    const topMargin = 16.0;

    final plotWidth = size.width - leftMargin - rightMargin;
    final plotHeight = size.height - topMargin - bottomMargin;

    // Grid paint
    final gridPaint = Paint()
      ..color = (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)).withValues(alpha: 0.8)
      ..strokeWidth = 1;

    // Determine max value for Y-axis scaling
    double maxY = 100.0;
    if (mode == 'count') {
      double maxFound = 5.0;
      for (final item in monthlyData) {
        final tot = ((item['total_programs'] ?? 0) as num).toDouble();
        if (tot > maxFound) maxFound = tot;
      }
      maxY = (maxFound * 1.2).ceilToDouble();
      if (maxY < 5) maxY = 5;
    }

    // Draw horizontal grid lines & Y-axis labels
    const gridSteps = 4;
    for (int i = 0; i <= gridSteps; i++) {
      final y = topMargin + (plotHeight * (i / gridSteps));
      canvas.drawLine(Offset(leftMargin, y), Offset(size.width - rightMargin, y), gridPaint);

      final val = maxY - (maxY * (i / gridSteps));
      final labelText = mode == 'count' ? val.toInt().toString() : '${val.toInt()}%';
      final tp = TextPainter(
        text: TextSpan(
          text: labelText,
          style: TextStyle(
            color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
            fontSize: 9,
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(leftMargin - tp.width - 6, y - tp.height / 2));
    }

    final n = monthlyData.length;
    final stepX = plotWidth / (n - 1);

    final completedPoints = <Offset>[];
    final inProgressPoints = <Offset>[];

    for (int i = 0; i < n; i++) {
      final item = monthlyData[i];
      double compVal = 0.0;
      double inProgVal = 0.0;

      if (mode == 'count') {
        compVal = ((item['completed_programs'] ?? 0) as num).toDouble();
        inProgVal = ((item['in_progress_programs'] ?? 0) as num).toDouble();
      } else if (mode == 'cumulative') {
        compVal = ((item['cum_completed_rate'] ?? item['completed_rate'] ?? 0) as num).toDouble();
        inProgVal = ((item['cum_in_progress_rate'] ?? item['in_progress_rate'] ?? 0) as num).toDouble();
      } else {
        compVal = ((item['completed_rate'] ?? 0) as num).toDouble();
        inProgVal = ((item['in_progress_rate'] ?? 0) as num).toDouble();
      }

      final x = leftMargin + (i * stepX);
      final yComp = topMargin + plotHeight - ((compVal.clamp(0, maxY) / maxY) * plotHeight);
      final yInProg = topMargin + plotHeight - ((inProgVal.clamp(0, maxY) / maxY) * plotHeight);

      completedPoints.add(Offset(x, yComp));
      inProgressPoints.add(Offset(x, yInProg));

      // Month Label
      final isHovered = hoveredIndex == i;
      final tp = TextPainter(
        text: TextSpan(
          text: item['month'] ?? '',
          style: TextStyle(
            color: isHovered
                ? const Color(0xFF4F46E5)
                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            fontSize: isHovered ? 10 : 9,
            fontWeight: isHovered ? FontWeight.bold : FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, Offset(x - tp.width / 2, size.height - bottomMargin + 8));
    }

    // Helper to build smooth Bezier path
    Path buildSmoothPath(List<Offset> points) {
      final path = Path();
      if (points.isEmpty) return path;
      path.moveTo(points[0].dx, points[0].dy);
      for (int i = 0; i < points.length - 1; i++) {
        final p0 = points[i];
        final p1 = points[i + 1];
        final cx = (p0.dx + p1.dx) / 2;
        path.cubicTo(cx, p0.dy, cx, p1.dy, p1.dx, p1.dy);
      }
      return path;
    }

    final completedPath = buildSmoothPath(completedPoints);
    final inProgressPath = buildSmoothPath(inProgressPoints);

    // Gradient fill under completed path
    final fillPathComp = Path.from(completedPath)
      ..lineTo(completedPoints.last.dx, topMargin + plotHeight)
      ..lineTo(completedPoints.first.dx, topMargin + plotHeight)
      ..close();

    final compGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF4F46E5).withValues(alpha: 0.18),
        const Color(0xFF4F46E5).withValues(alpha: 0.0),
      ],
    );
    final compShader = compGradient.createShader(Rect.fromLTWH(leftMargin, topMargin, plotWidth, plotHeight));
    canvas.drawPath(fillPathComp, Paint()..shader = compShader);

    // Lines paint
    final completedLinePaint = Paint()
      ..color = const Color(0xFF4F46E5)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final inProgressLinePaint = Paint()
      ..color = const Color(0xFF0284C7)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(completedPath, completedLinePaint);
    canvas.drawPath(inProgressPath, inProgressLinePaint);

    // Draw vertical indicator line if hovered
    if (hoveredIndex != null && hoveredIndex! >= 0 && hoveredIndex! < n) {
      final hX = leftMargin + (hoveredIndex! * stepX);
      final guidePaint = Paint()
        ..color = const Color(0xFF4F46E5).withValues(alpha: 0.4)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(hX, topMargin), Offset(hX, topMargin + plotHeight), guidePaint);
    }

    // Draw dots
    for (int i = 0; i < n; i++) {
      final isHovered = hoveredIndex == i;
      final cPt = completedPoints[i];
      final pPt = inProgressPoints[i];

      if (isHovered) {
        // Outer halo
        canvas.drawCircle(cPt, 7, Paint()..color = const Color(0xFF4F46E5).withValues(alpha: 0.25));
        canvas.drawCircle(pPt, 7, Paint()..color = const Color(0xFF0284C7).withValues(alpha: 0.25));
      }

      // Point dots
      canvas.drawCircle(cPt, isHovered ? 4.5 : 3.0, Paint()..color = const Color(0xFF4F46E5));
      canvas.drawCircle(cPt, isHovered ? 2.5 : 1.5, Paint()..color = Colors.white);

      canvas.drawCircle(pPt, isHovered ? 4.5 : 3.0, Paint()..color = const Color(0xFF0284C7));
      canvas.drawCircle(pPt, isHovered ? 2.5 : 1.5, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) =>
      oldDelegate.monthlyData != monthlyData ||
      oldDelegate.isDark != isDark ||
      oldDelegate.hoveredIndex != hoveredIndex ||
      oldDelegate.mode != mode;
}
