import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../constants/app_fonts.dart';
import '../../utils/download_helper.dart';
import 'services/exams_api_service.dart';
import 'services/question_bank_lookup_helper.dart';
import 'utils/exam_nav_helper.dart';

typedef TeacherExams = ExamsManagementScreen;

class ExamsManagementScreen extends ConsumerStatefulWidget {
  const ExamsManagementScreen({super.key});

  @override
  ConsumerState<ExamsManagementScreen> createState() =>
      _ExamsManagementScreenState();
}

class _ExamsManagementScreenState extends ConsumerState<ExamsManagementScreen> {
  final ExamsApiService _apiService = ExamsApiService.instance;

  // Overview data
  bool _isLoadingOverview = true;
  Map<String, dynamic> _kpis = {
    'total_exams': 0,
    'total_exams_change': '0%',
    'total_students_appeared': 0,
    'total_students_appeared_change': '0%',
    'average_score': 0.0,
    'average_score_change': '0%',
    'pass_percentage': 0.0,
    'pass_percentage_change': '0%',
  };
  Map<String, dynamic> _tabCounts = {
    'all': 0,
    'upcoming': 0,
    'ongoing': 0,
    'completed': 0,
  };
  List<Map<String, dynamic>> _performanceChart = [];
  List<Map<String, dynamic>> _topPerformers = [];
  List<Map<String, dynamic>> _recentActivities = [];

  // Table & Filter state
  bool _isLoadingTable = true;
  List<Map<String, dynamic>> _exams = [];
  Set<String> _selectedExamIds = {};
  String _activeStatusTab = 'all'; // all, upcoming, ongoing, completed
  final TextEditingController _searchController = TextEditingController();
  String _selectedClass = 'All Classes';
  String _selectedType = 'All Types';
  String _selectedStatus = 'All Status';
  String _dateRangeText = 'All Dates';
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

  // Pagination & Sorting
  int _currentPage = 1;
  int _pageSize = 10;
  int _totalCount = 24;
  int _totalPages = 3;
  String? _sortBy;
  String _sortOrder = 'asc';

  // Lookups
  List<String> _classList = ['All Classes'];
  List<Map<String, dynamic>> _classesWithSections = [];
  List<String> _typeList = ['All Types'];
  List<String> _statusList = [
    'All Status',
    'Scheduled',
    'Ongoing',
    'Completed'
  ];
  List<QuestionBankLookupItem> _academicSessionLookups = [];
  List<QuestionBankLookupItem> _examCategoryLookups = [];
  List<QuestionBankLookupItem> _examModeLookups = [];

  // Calendar State
  DateTime _currentCalendarMonth = DateTime.now();
  Set<int> get _highlightedCalendarDays {
    final days = <int>{};
    for (final ev in _exams) {
      final dStr = (ev['exam_date'] ?? ev['date'])?.toString();
      if (dStr != null) {
        try {
          final dt = DateTime.parse(dStr.split('T')[0]);
          if (dt.year == _currentCalendarMonth.year &&
              dt.month == _currentCalendarMonth.month) {
            days.add(dt.day);
          }
        } catch (_) {}
      }
    }
    return days;
  }

  // Dynamic Theme Helpers
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bgCol =>
      _isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
  Color get _cardBg => _isDark ? const Color(0xFF1E293B) : Colors.white;
  Color get _innerCardBg =>
      _isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
  Color get _cardBorder =>
      _isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
  Color get _textPrimary =>
      _isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
  Color get _textSecondary =>
      _isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  Color get _inputBg =>
      _isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _loadLookups();
    _loadDashboardOverview();
    _loadExamsTable();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLookups() async {
    try {
      final helper = QuestionBankLookupHelper.instance;
      final results = await Future.wait([
        _apiService.getExamManagementLookups(),
        helper.getAcademicSessions(),
        helper.getExamCategories(),
        helper.getExamModes(),
        helper.getExamStatuses(),
        _apiService.getQuestionBankClasses(),
      ]);

      if (!mounted) return;

      final res = results[0] as Map<String, dynamic>;
      final sessions = results[1] as List<QuestionBankLookupItem>;
      final cats = results[2] as List<QuestionBankLookupItem>;
      final modes = results[3] as List<QuestionBankLookupItem>;
      final statuses = results[4] as List<QuestionBankLookupItem>;
      final qbClasses = results[5] as List<String>;

      final rawClasses =
          (res['classes'] as List? ?? []).map((e) => e.toString()).toList();
      final rawClassesWithSections =
          (res['classes_with_sections'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();

      final combinedClasses = <String>{};
      combinedClasses.addAll(rawClasses);
      combinedClasses.addAll(qbClasses);
      if (combinedClasses.isEmpty) {
        combinedClasses.addAll([
          'Class 5',
          'Class 6',
          'Class 7',
          'Class 8',
          'Class 9',
          'Class 10',
          'Class 11',
          'Class 12'
        ]);
      }

      setState(() {
        _academicSessionLookups = sessions;
        _examCategoryLookups = cats;
        _examModeLookups = modes;
        _classesWithSections = rawClassesWithSections;
        _classList = ['All Classes', ...combinedClasses];
        if (cats.isNotEmpty) {
          _typeList = ['All Types', ...cats.map((c) => c.name)];
        }
        if (statuses.isNotEmpty) {
          _statusList = ['All Status', ...statuses.map((s) => s.name)];
        }
      });
    } catch (_) {}
  }

  Future<void> _loadDashboardOverview() async {
    if (!mounted) return;
    setState(() => _isLoadingOverview = true);
    try {
      final data = await _apiService.getExamsDashboardOverview();
      if (mounted && data.isNotEmpty) {
        setState(() {
          if (data['kpis'] is Map) {
            _kpis = Map<String, dynamic>.from(data['kpis']);
          }
          if (data['tab_counts'] is Map) {
            _tabCounts = Map<String, dynamic>.from(data['tab_counts']);
          }
          if (data['performance_chart'] is List) {
            _performanceChart = (data['performance_chart'] as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
          }
          if (data['top_performers'] is List) {
            _topPerformers = (data['top_performers'] as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
          }
          if (data['recent_activities'] is List) {
            _recentActivities = (data['recent_activities'] as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
          }
          _isLoadingOverview = false;
        });
      } else {
        if (mounted) setState(() => _isLoadingOverview = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingOverview = false);
    }
  }

  Future<void> _loadExamsTable() async {
    if (!mounted) return;
    setState(() => _isLoadingTable = true);
    try {
      final res = await _apiService.getExamsPaged(
        statusTab: _activeStatusTab,
        search: _searchController.text,
        className: _selectedClass,
        type: _selectedType,
        status: _selectedStatus,
        startDate: _filterStartDate?.toIso8601String().split('T')[0],
        endDate: _filterEndDate?.toIso8601String().split('T')[0],
        page: _currentPage,
        pageSize: _pageSize,
        sortBy: _sortBy,
        sortOrder: _sortOrder,
      );

      if (mounted) {
        setState(() {
          _exams = (res['exams'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _totalCount = res['total_count'] ?? _exams.length;
          _totalPages = res['total_pages'] ?? 1;
          if (res['tab_counts'] is Map &&
              (res['tab_counts'] as Map).isNotEmpty) {
            _tabCounts = Map<String, dynamic>.from(res['tab_counts']);
          }
          _selectedExamIds.clear();
          _isLoadingTable = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingTable = false);
    }
  }

  void _onStatusTabSelected(String tabKey) {
    if (_activeStatusTab == tabKey) return;
    setState(() {
      _activeStatusTab = tabKey;
      _currentPage = 1;
    });
    _loadExamsTable();
  }

  void _applyFilters() {
    setState(() => _currentPage = 1);
    _loadExamsTable();
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _selectedClass = 'All Classes';
      _selectedType = 'All Types';
      _selectedStatus = 'All Status';
      _activeStatusTab = 'all';
      _filterStartDate = null;
      _filterEndDate = null;
      _dateRangeText = 'All Dates';
      _currentPage = 1;
    });
    _loadExamsTable();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1150;

    return Scaffold(
      backgroundColor: _bgCol,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopHeader(context),
              const SizedBox(height: 20),
              _buildKpiCardsRow(),
              const SizedBox(height: 24),
              if (isDesktop) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 72,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildStatusTabsHeader(),
                          const SizedBox(height: 14),
                          _buildFilterToolbar(),
                          if (_selectedExamIds.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _buildBulkActionsBar(),
                          ],
                          const SizedBox(height: 14),
                          _buildExamsTableCard(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      flex: 28,
                      child: Column(
                        children: [
                          _buildExamCalendarCard(),
                          const SizedBox(height: 20),
                          _buildQuickActionsCard(),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildBottomAnalyticsRow(),
              ] else ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatusTabsHeader(),
                    const SizedBox(height: 14),
                    _buildFilterToolbar(),
                    if (_selectedExamIds.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _buildBulkActionsBar(),
                    ],
                    const SizedBox(height: 14),
                    _buildExamsTableCard(),
                    const SizedBox(height: 20),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        if (constraints.maxWidth >= 600) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildExamCalendarCard()),
                              const SizedBox(width: 16),
                              Expanded(child: _buildQuickActionsCard()),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            _buildExamCalendarCard(),
                            const SizedBox(height: 16),
                            _buildQuickActionsCard(),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    _buildBottomAnalyticsRow(),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // 1. TOP HEADER & NAVIGATION
  // ============================================================================

  Widget _buildTopHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.event_note_rounded,
                  color: Color(0xFF3B82F6), size: 24),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Examinations',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                    fontFamily: AppFonts.heading,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Manage exams, create results and analyze performance',
                  style: TextStyle(
                    fontSize: 13,
                    color: _textSecondary,
                    fontFamily: AppFonts.body,
                  ),
                ),
              ],
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: () => _openCreateExamDialog(context),
          icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
          label: const Row(
            children: [
              Text(
                'Create Examination',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white),
              ),
              SizedBox(width: 4),
              Icon(Icons.arrow_drop_down_rounded,
                  size: 18, color: Colors.white),
            ],
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // 2. KPI CARDS ROW (4 CARDS)
  // ============================================================================

  Widget _buildKpiCardsRow() {
    if (_isLoadingOverview) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: LinearProgressIndicator(),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 36) / 4;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildKpiCard(
              title: 'Total Exams',
              value: '${_kpis['total_exams'] ?? 24}',
              badge: _kpis['total_exams_change'] ?? '↑ 8%',
              icon: Icons.calendar_today_rounded,
              iconColor: const Color(0xFF2563EB),
              iconBgColor: const Color(0xFFEFF6FF),
              width: cardWidth > 200 ? cardWidth : constraints.maxWidth / 2 - 8,
            ),
            _buildKpiCard(
              title: 'Total Students Appeared',
              value: '${_kpis['total_students_appeared'] ?? 1248}',
              badge: _kpis['total_students_appeared_change'] ?? '↑ 5%',
              icon: Icons.groups_rounded,
              iconColor: const Color(0xFF16A34A),
              iconBgColor: const Color(0xFFF0FDF4),
              width: cardWidth > 200 ? cardWidth : constraints.maxWidth / 2 - 8,
            ),
            _buildKpiCard(
              title: 'Average Score',
              value: '${_kpis['average_score'] ?? 78.5}%',
              badge: _kpis['average_score_change'] ?? '↑ 2%',
              icon: Icons.emoji_events_rounded,
              iconColor: const Color(0xFF9333EA),
              iconBgColor: const Color(0xFFFAF5FF),
              width: cardWidth > 200 ? cardWidth : constraints.maxWidth / 2 - 8,
            ),
            _buildKpiCard(
              title: 'Pass Percentage',
              value: '${_kpis['pass_percentage'] ?? 96.2}%',
              badge: _kpis['pass_percentage_change'] ?? '↑ 1%',
              icon: Icons.bar_chart_rounded,
              iconColor: const Color(0xFFEA580C),
              iconBgColor: const Color(0xFFFFF7ED),
              width: cardWidth > 200 ? cardWidth : constraints.maxWidth / 2 - 8,
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String badge,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
        boxShadow: const [
          BoxShadow(
              color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _isDark ? iconColor.withValues(alpha: 0.18) : iconBgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: _textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _isDark
                            ? const Color(0xFF064E3B).withValues(alpha: 0.3)
                            : const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: _isDark
                              ? const Color(0xFF4ADE80)
                              : const Color(0xFF16A34A),
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
    );
  }

  // ============================================================================
  // 3. HORIZONTAL STATUS TABS (ALL, UPCOMING, ONGOING, COMPLETED)
  // ============================================================================

  Widget _buildStatusTabsHeader() {
    final allCount = _tabCounts['all'] ?? _exams.length;
    final upcomingCount = _tabCounts['upcoming'] ?? 0;
    final ongoingCount = _tabCounts['ongoing'] ?? 0;
    final completedCount = _tabCounts['completed'] ?? 0;

    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _cardBorder)),
      ),
      child: Row(
        children: [
          _buildStatusTabItem(title: 'All Exams ($allCount)', key: 'all'),
          const SizedBox(width: 8),
          _buildStatusTabItem(
              title: 'Upcoming ($upcomingCount)', key: 'upcoming'),
          const SizedBox(width: 8),
          _buildStatusTabItem(title: 'Ongoing ($ongoingCount)', key: 'ongoing'),
          const SizedBox(width: 8),
          _buildStatusTabItem(
              title: 'Completed ($completedCount)', key: 'completed'),
        ],
      ),
    );
  }

  Widget _buildStatusTabItem({required String title, required String key}) {
    final isActive = _activeStatusTab == key;
    return InkWell(
      onTap: () => _onStatusTabSelected(key),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? const Color(0xFF2563EB) : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? const Color(0xFF3B82F6) : _textSecondary,
          ),
        ),
      ),
    );
  }

  // ============================================================================
  // 4. FILTER TOOLBAR & BULK ACTIONS
  // ============================================================================

  Widget _buildFilterToolbar() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 960;

        if (isWide) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _cardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _cardBorder),
            ),
            child: Row(
              children: [
                // Search Field expanding smoothly
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 38,
                    child: TextField(
                      controller: _searchController,
                      onSubmitted: (_) => _applyFilters(),
                      style: TextStyle(fontSize: 13, color: _textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search exams...',
                        hintStyle:
                            TextStyle(color: _textSecondary, fontSize: 13),
                        prefixIcon: Icon(Icons.search_rounded,
                            size: 18, color: _textSecondary),
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 0, horizontal: 10),
                        filled: true,
                        fillColor: _inputBg,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: _cardBorder)),
                        enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: _cardBorder)),
                        focusedBorder: const OutlineInputBorder(
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                            borderSide: BorderSide(color: Color(0xFF2563EB))),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Class Dropdown
                _buildFilterDropdown(
                  value: _selectedClass,
                  items: _classList,
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedClass = val);
                      _applyFilters();
                    }
                  },
                ),
                const SizedBox(width: 8),

                // Type Dropdown
                _buildFilterDropdown(
                  value: _selectedType,
                  items: _typeList,
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedType = val);
                      _applyFilters();
                    }
                  },
                ),
                const SizedBox(width: 8),

                // Status Dropdown
                _buildFilterDropdown(
                  value: _selectedStatus,
                  items: _statusList,
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedStatus = val);
                      _applyFilters();
                    }
                  },
                ),
                const SizedBox(width: 8),

                // Date Range Button
                _buildDateRangeButton(),
                const SizedBox(width: 8),

                // Blue Filter Button
                ElevatedButton.icon(
                  onPressed: _applyFilters,
                  icon: const Icon(Icons.filter_list_rounded,
                      size: 16, color: Colors.white),
                  label: const Text('Filter',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(width: 6),

                // Reset Button
                TextButton(
                  onPressed: _resetFilters,
                  child: Text('Reset',
                      style: TextStyle(
                          fontSize: 13,
                          color: _textSecondary,
                          fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          );
        }

        // Medium or Mobile (Adaptive Responsive Layout)
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _searchController,
                        onSubmitted: (_) => _applyFilters(),
                        style: TextStyle(fontSize: 13, color: _textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Search exams...',
                          hintStyle:
                              TextStyle(color: _textSecondary, fontSize: 13),
                          prefixIcon: Icon(Icons.search_rounded,
                              size: 18, color: _textSecondary),
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 0, horizontal: 10),
                          filled: true,
                          fillColor: _inputBg,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: _cardBorder)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: _cardBorder)),
                          focusedBorder: const OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(8)),
                              borderSide: BorderSide(color: Color(0xFF2563EB))),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _applyFilters,
                    icon: const Icon(Icons.filter_list_rounded,
                        size: 16, color: Colors.white),
                    label: const Text('Filter',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 4),
                  TextButton(
                    onPressed: _resetFilters,
                    child: Text('Reset',
                        style: TextStyle(
                            fontSize: 13,
                            color: _textSecondary,
                            fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _buildFilterDropdown(
                    value: _selectedClass,
                    items: _classList,
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedClass = val);
                        _applyFilters();
                      }
                    },
                  ),
                  _buildFilterDropdown(
                    value: _selectedType,
                    items: _typeList,
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedType = val);
                        _applyFilters();
                      }
                    },
                  ),
                  _buildFilterDropdown(
                    value: _selectedStatus,
                    items: _statusList,
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedStatus = val);
                        _applyFilters();
                      }
                    },
                  ),
                  _buildDateRangeButton(),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDateRangeButton() {
    return InkWell(
      onTap: _pickDateRange,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: _inputBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_month_outlined,
                size: 16, color: _textSecondary),
            const SizedBox(width: 6),
            Text(_dateRangeText,
                style: TextStyle(
                    fontSize: 12,
                    color: _textPrimary,
                    fontWeight: FontWeight.w500)),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded,
                size: 16, color: _textSecondary),
          ],
        ),
      ),
    );
  }

  /// Bulk Actions Toolbar when checkboxes are selected
  Widget _buildBulkActionsBar() {
    final count = _selectedExamIds.length;
    final isAllSelected =
        _selectedExamIds.length == _exams.length && _exams.isNotEmpty;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: _isDark ? const Color(0xFF1E293B) : const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _isDark
              ? const Color(0xFF3B82F6).withValues(alpha: 0.5)
              : const Color(0xFF93C5FD),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_rounded,
                    size: 16, color: Color(0xFF2563EB)),
              ),
              const SizedBox(width: 8),
              Text(
                '$count examination${count > 1 ? 's' : ''} selected',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _isDark ? Colors.white : const Color(0xFF1E3A8A),
                ),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: () {
                  setState(() {
                    if (isAllSelected) {
                      _selectedExamIds.clear();
                    } else {
                      _selectedExamIds =
                          _exams.map((e) => e['id'].toString()).toSet();
                    }
                  });
                },
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  visualDensity: VisualDensity.compact,
                ),
                child: Text(
                  isAllSelected
                      ? 'Deselect All'
                      : 'Select All (${_exams.length})',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2563EB)),
                ),
              ),
            ],
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Bulk Publish
              ElevatedButton.icon(
                onPressed: _bulkPublishResults,
                icon: const Icon(Icons.verified_rounded,
                    size: 15, color: Colors.white),
                label: const Text('Publish Results',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
              ),
              const SizedBox(width: 8),

              // Bulk Status Update
              OutlinedButton.icon(
                onPressed: _showBulkStatusDialog,
                icon: Icon(Icons.sync_rounded,
                    size: 15,
                    color: _isDark ? Colors.white : const Color(0xFF0F172A)),
                label: Text('Change Status',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color:
                            _isDark ? Colors.white : const Color(0xFF0F172A))),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _cardBorder),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
              ),
              const SizedBox(width: 8),

              // Bulk Export / Hall Tickets
              OutlinedButton.icon(
                onPressed: _bulkExportHallTickets,
                icon: Icon(Icons.download_rounded,
                    size: 15,
                    color: _isDark ? Colors.white : const Color(0xFF0F172A)),
                label: Text('Export Schedules',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color:
                            _isDark ? Colors.white : const Color(0xFF0F172A))),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _cardBorder),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
              ),
              const SizedBox(width: 8),

              // Bulk Delete
              ElevatedButton.icon(
                onPressed: _bulkDeleteExams,
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 15, color: Colors.white),
                label: const Text('Delete',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
              ),
              const SizedBox(width: 4),

              // Dismiss / Deselect
              IconButton(
                icon:
                    Icon(Icons.close_rounded, size: 18, color: _textSecondary),
                tooltip: 'Clear Selection',
                onPressed: () => setState(() => _selectedExamIds.clear()),
                splashRadius: 16,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _bulkPublishResults() async {
    final count = _selectedExamIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Bulk Publish Results',
            style: TextStyle(fontWeight: FontWeight.w700, color: _textPrimary)),
        content: Text(
            'Are you sure you want to publish results for $count selected examination(s)? This will notify students and guardians.',
            style: TextStyle(fontSize: 13, color: _textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel', style: TextStyle(color: _textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm & Publish',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      final res = await _apiService.bulkPublishExams(_selectedExamIds.toList());
      final publishedCount = res['updated_count'] ?? count;
      setState(() {
        _selectedExamIds.clear();
      });
      _loadDashboardOverview();
      _loadExamsTable();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Results successfully published for $publishedCount examination(s)!'),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bulk publish failed: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _showBulkStatusDialog() async {
    final count = _selectedExamIds.length;
    String targetStatus = 'Scheduled';

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: _cardBg,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text('Change Status ($count Exams)',
              style:
                  TextStyle(fontWeight: FontWeight.w700, color: _textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Select the new status to apply to all $count selected examinations:',
                  style: TextStyle(fontSize: 13, color: _textSecondary)),
              const SizedBox(height: 14),
              AppSearchableDropdownFormField<String>.fromMenuItems(
                initialValue: targetStatus,
                dropdownColor: _cardBg,
                style: TextStyle(color: _textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Target Status',
                  labelStyle: TextStyle(color: _textSecondary),
                  filled: true,
                  fillColor: _inputBg,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: _cardBorder)),
                ),
                items: const [
                  DropdownMenuItem(
                      value: 'Scheduled', child: Text('Scheduled')),
                  DropdownMenuItem(value: 'Ongoing', child: Text('Ongoing')),
                  DropdownMenuItem(
                      value: 'Completed', child: Text('Completed')),
                  DropdownMenuItem(
                      value: 'Cancelled', child: Text('Cancelled')),
                ],
                onChanged: (v) {
                  if (v != null) setDlgState(() => targetStatus = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('Cancel', style: TextStyle(color: _textSecondary))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB)),
              onPressed: () => Navigator.of(ctx).pop(targetStatus),
              child: const Text('Apply Status',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (result == null || !mounted) return;

    try {
      final res = await _apiService.bulkUpdateExamStatus(
          _selectedExamIds.toList(), result);
      final updatedCount = res['updated_count'] ?? count;
      setState(() {
        _selectedExamIds.clear();
      });
      _loadDashboardOverview();
      _loadExamsTable();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Updated status to "$result" for $updatedCount examination(s)!'),
            backgroundColor: const Color(0xFF2563EB),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bulk status update failed: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _bulkExportHallTickets() async {
    final count = _selectedExamIds.length;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Generating schedule export bundle for $count examination(s)...'),
        backgroundColor: const Color(0xFF2563EB),
        duration: const Duration(seconds: 2),
      ),
    );
    try {
      final csvBytes =
          await _apiService.bulkExportSchedules(_selectedExamIds.toList());
      final filename =
          'exam_schedules_export_${DateTime.now().millisecondsSinceEpoch}.csv';
      await getDownloadHelper().downloadBytes(csvBytes, filename);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exam schedules exported successfully ($filename)!'),
            backgroundColor: const Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Schedule export failed: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  Future<void> _bulkDeleteExams() async {
    final count = _selectedExamIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
            const SizedBox(width: 8),
            Text('Confirm Deletion',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: _textPrimary)),
          ],
        ),
        content: Text(
            'Are you sure you want to permanently delete $count selected examination(s)? This action cannot be undone.',
            style: TextStyle(fontSize: 13, color: _textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel', style: TextStyle(color: _textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete Permanently',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    for (final id in _selectedExamIds) {
      try {
        await _apiService.deleteExam(id);
      } catch (_) {}
    }

    setState(() {
      _exams.removeWhere((e) => _selectedExamIds.contains(e['id']?.toString()));
      _selectedExamIds.clear();
    });
    _loadDashboardOverview();
    _loadExamsTable();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully removed $count examination(s).'),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  Widget _buildFilterDropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    final validVal = items.contains(value) ? value : items.first;
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: _inputBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _cardBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: AppSearchableDropdown<String>.fromMenuItems(
          value: validVal,
          dropdownColor: _cardBg,
          icon: Icon(Icons.keyboard_arrow_down_rounded,
              size: 18, color: _textSecondary),
          style: TextStyle(
              fontSize: 12.5, color: _textPrimary, fontWeight: FontWeight.w500),
          items: items
              .map((it) => DropdownMenuItem(
                  value: it,
                  child: Text(it, style: TextStyle(color: _textPrimary))))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
      initialDateRange: DateTimeRange(
        start: _filterStartDate ?? DateTime(now.year, now.month, 1),
        end: _filterEndDate ?? DateTime(now.year, now.month + 1, 0),
      ),
      builder: (context, child) => Theme(
        data: ThemeData(
          brightness: _isDark ? Brightness.dark : Brightness.light,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2563EB),
            brightness: _isDark ? Brightness.dark : Brightness.light,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _filterStartDate = picked.start;
        _filterEndDate = picked.end;
        _dateRangeText =
            '${picked.start.day} ${_monthName(picked.start.month)} ${picked.start.year} - ${picked.end.day} ${_monthName(picked.end.month)} ${picked.end.year}';
      });
      _applyFilters();
    }
  }

  String _monthName(int m) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return months[m - 1];
  }

  // ============================================================================
  // 5. EXAMS DATA TABLE & PAGINATION
  // ============================================================================

  Widget _buildExamsTableCard() {
    return Container(
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
        boxShadow: const [
          BoxShadow(
              color: Color(0x06000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // Table Content
          if (_isLoadingTable)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF2563EB))),
            )
          else if (_exams.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.event_busy_rounded,
                        size: 48, color: _textSecondary),
                    const SizedBox(height: 12),
                    Text('No examinations found',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _textPrimary)),
                    const SizedBox(height: 4),
                    Text(
                        'Try adjusting your search criteria or create a new examination.',
                        style: TextStyle(fontSize: 13, color: _textSecondary)),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _openCreateExamDialog(context),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Create Examination'),
                      style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white),
                    )
                  ],
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final tableMinWidth =
                    constraints.maxWidth > 800 ? constraints.maxWidth : 800.0;
                final spacing = constraints.maxWidth > 950
                    ? (constraints.maxWidth - 650) / 7.0
                    : 18.0;

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: tableMinWidth),
                    child: DataTable(
                      onSelectAll: (val) {
                        setState(() {
                          if (val == true) {
                            for (final ex in _exams) {
                              final id = ex['id']?.toString();
                              if (id != null && id.isNotEmpty) {
                                _selectedExamIds.add(id);
                              }
                            }
                          } else {
                            _selectedExamIds.clear();
                          }
                        });
                      },
                      headingRowColor: WidgetStateProperty.all(_innerCardBg),
                      headingTextStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _textSecondary,
                        letterSpacing: 0.3,
                      ),
                      dataRowColor: WidgetStateProperty.resolveWith<Color?>(
                          (Set<WidgetState> states) {
                        if (states.contains(WidgetState.selected)) {
                          return const Color(0xFF2563EB)
                              .withValues(alpha: _isDark ? 0.2 : 0.08);
                        }
                        return _cardBg;
                      }),
                      horizontalMargin: 16,
                      columnSpacing: spacing.clamp(14.0, 48.0),
                      sortColumnIndex: const [null, 'title', 'class', 'type', 'date', null, 'status', null]
                          .indexOf(_sortBy) >= 0
                          ? const [null, 'title', 'class', 'type', 'date', null, 'status', null].indexOf(_sortBy)
                          : null,
                      sortAscending: _sortOrder == 'asc',
                      columns: [
                        const DataColumn(label: Text('#')),
                        DataColumn(
                          label: const Text('Exam Name'),
                          onSort: (_, asc) {
                            setState(() {
                              _sortBy = 'title';
                              _sortOrder = asc ? 'asc' : 'desc';
                              _currentPage = 1;
                            });
                            _loadExamsTable();
                          },
                        ),
                        DataColumn(
                          label: const Text('Class'),
                          onSort: (_, asc) {
                            setState(() {
                              _sortBy = 'class';
                              _sortOrder = asc ? 'asc' : 'desc';
                              _currentPage = 1;
                            });
                            _loadExamsTable();
                          },
                        ),
                        DataColumn(
                          label: const Text('Type'),
                          onSort: (_, asc) {
                            setState(() {
                              _sortBy = 'type';
                              _sortOrder = asc ? 'asc' : 'desc';
                              _currentPage = 1;
                            });
                            _loadExamsTable();
                          },
                        ),
                        DataColumn(
                          label: const Text('Date'),
                          onSort: (_, asc) {
                            setState(() {
                              _sortBy = 'date';
                              _sortOrder = asc ? 'asc' : 'desc';
                              _currentPage = 1;
                            });
                            _loadExamsTable();
                          },
                        ),
                        const DataColumn(label: Text('Time')),
                        DataColumn(
                          label: const Text('Status'),
                          onSort: (_, asc) {
                            setState(() {
                              _sortBy = 'status';
                              _sortOrder = asc ? 'asc' : 'desc';
                              _currentPage = 1;
                            });
                            _loadExamsTable();
                          },
                        ),
                        const DataColumn(label: Text('Actions')),
                      ],
                      rows: List.generate(_exams.length, (index) {
                        final ex = _exams[index];
                        final id = ex['id']?.toString() ?? '';
                        final isSelected = _selectedExamIds.contains(id);
                        final serialNum =
                            (_currentPage - 1) * _pageSize + index + 1;

                        return DataRow(
                          selected: isSelected,
                          onSelectChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _selectedExamIds.add(id);
                              } else {
                                _selectedExamIds.remove(id);
                              }
                            });
                          },
                          cells: [
                            DataCell(Text('$serialNum',
                                style: TextStyle(
                                    fontSize: 12.5, color: _textSecondary))),
                            DataCell(
                              Text(
                                ex['title'] ?? 'Institutional Exam',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: _textPrimary,
                                ),
                              ),
                            ),
                            DataCell(Text(ex['class'] ?? 'Class 10',
                                style: TextStyle(
                                    fontSize: 12.5, color: _textSecondary))),
                            DataCell(Text(ex['type'] ?? 'Exam',
                                style: TextStyle(
                                    fontSize: 12.5, color: _textSecondary))),
                            DataCell(Text(ex['date'] ?? '-',
                                style: TextStyle(
                                    fontSize: 12.5, color: _textSecondary))),
                            DataCell(Text(ex['time'] ?? '09:00 AM',
                                style: TextStyle(
                                    fontSize: 12.5, color: _textSecondary))),
                            DataCell(
                                _buildStatusBadge(ex['status'] ?? 'Scheduled')),
                            DataCell(_buildRowActions(ex)),
                          ],
                        );
                      }),
                    ),
                  ),
                );
              },
            ),
          // Pagination Bar
          Divider(height: 1, color: _cardBorder),
          _buildPaginationBar(),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg = const Color(0xFFE0F2FE);
    Color txt = const Color(0xFF0369A1);

    final s = status.toLowerCase().trim();
    if (s == 'scheduled') {
      bg = const Color(0xFFDCFCE7);
      txt = const Color(0xFF15803D);
    } else if (s == 'ongoing') {
      bg = const Color(0xFFFEF3C7);
      txt = const Color(0xFFB45309);
    } else if (s == 'completed') {
      bg = const Color(0xFFE0F2FE);
      txt = const Color(0xFF0369A1);
    } else if (s == 'draft') {
      bg = const Color(0xFFF1F5F9);
      txt = const Color(0xFF475569);
    } else if (s == 'cancelled') {
      bg = const Color(0xFFFEE2E2);
      txt = const Color(0xFFDC2626);
    }

    return Container(
      constraints: const BoxConstraints(minWidth: 78),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          status,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.visible,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: txt,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  Widget _buildRowActions(Map<String, dynamic> exam) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // View Details / Date Sheet
        IconButton(
          icon: const Icon(Icons.visibility_outlined,
              size: 18, color: Color(0xFF64748B)),
          tooltip: 'View Date Sheet & Details',
          splashRadius: 18,
          onPressed: () => _openScheduleDialog(exam),
        ),
        // Edit Exam
        IconButton(
          icon: const Icon(Icons.edit_outlined,
              size: 18, color: Color(0xFF64748B)),
          tooltip: 'Edit Examination',
          splashRadius: 18,
          onPressed: () => _openEditExamDialog(exam),
        ),
        // More context menu
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded,
              size: 18, color: Color(0xFF64748B)),
          tooltip: 'More Actions',
          splashRadius: 18,
          onSelected: (action) => _handleExamAction(action, exam),
          itemBuilder: (context) {
            final base = getExamsBaseRoute(context);
            final canMonitor = !base.startsWith('/student');
            return [
              const PopupMenuItem(
                value: 'take_exam',
                child: Row(
                  children: [
                    Icon(Icons.play_circle_fill_rounded,
                        size: 16, color: Color(0xFF2563EB)),
                    SizedBox(width: 8),
                    Text('Take Exam',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2563EB))),
                  ],
                ),
              ),
              if (canMonitor)
                const PopupMenuItem(
                  value: 'live_monitoring',
                  child: Row(
                    children: [
                      Icon(Icons.monitor_heart_rounded,
                          size: 16, color: Color(0xFF0D9488)),
                      SizedBox(width: 8),
                      Text('Live Exam Monitoring',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0D9488))),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'build_paper',
                child: Row(
                  children: [
                    Icon(Icons.build_rounded,
                        size: 16, color: Color(0xFF2563EB)),
                    SizedBox(width: 8),
                    Text('Build / Edit Paper', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'marks_entry',
                child: Row(
                  children: [
                    Icon(Icons.fact_check_outlined,
                        size: 16, color: Color(0xFF16A34A)),
                    SizedBox(width: 8),
                    Text('Marks Entry', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'view_results',
                child: Row(
                  children: [
                    Icon(Icons.emoji_events_outlined,
                        size: 16, color: Color(0xFFEA580C)),
                    SizedBox(width: 8),
                    Text('Results & Ranking', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'download_pdf',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf_outlined,
                        size: 16, color: Color(0xFF9333EA)),
                    SizedBox(width: 8),
                    Text('Download Question Paper',
                        style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded,
                        size: 16, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete Examination',
                        style: TextStyle(fontSize: 13, color: Colors.red)),
                  ],
                ),
              ),
            ];
          },
        ),
      ],
    );
  }

  void _handleExamAction(String action, Map<String, dynamic> exam) async {
    final examId = exam['id']?.toString() ?? '';
    final base = getExamsBaseRoute(context);

    if (action == 'take_exam') {
      context.go('$base/instructions?examId=$examId');
    } else if (action == 'live_monitoring') {
      context.go('$base/monitor/$examId');
    } else if (action == 'build_paper') {
      context.go('$base/paper-builder?examId=$examId');
    } else if (action == 'marks_entry') {
      _openMarksEntryDialog(exam);
    } else if (action == 'view_results') {
      _openResultsDialog(exam);
    } else if (action == 'download_pdf') {
      _downloadExamPdf(examId);
    } else if (action == 'delete') {
      _confirmDeleteExam(exam);
    }
  }

  Widget _buildPaginationBar() {
    final startIdx = _exams.isEmpty ? 0 : (_currentPage - 1) * _pageSize + 1;
    final endIdx = math.min(_currentPage * _pageSize, _totalCount);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Showing $startIdx - $endIdx of $_totalCount examinations',
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B)),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.first_page_rounded, size: 20),
                onPressed: _currentPage > 1 ? () => _goToPage(1) : null,
                splashRadius: 18,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded, size: 20),
                onPressed:
                    _currentPage > 1 ? () => _goToPage(_currentPage - 1) : null,
                splashRadius: 18,
              ),
              ...List.generate(math.min(_totalPages, 5), (i) {
                final pageNum = i + 1;
                final isCurrent = pageNum == _currentPage;
                return InkWell(
                  onTap: () => _goToPage(pageNum),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? const Color(0xFF2563EB)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '$pageNum',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight:
                            isCurrent ? FontWeight.w700 : FontWeight.w500,
                        color:
                            isCurrent ? Colors.white : const Color(0xFF475569),
                      ),
                    ),
                  ),
                );
              }),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded, size: 20),
                onPressed: _currentPage < _totalPages
                    ? () => _goToPage(_currentPage + 1)
                    : null,
                splashRadius: 18,
              ),
              IconButton(
                icon: const Icon(Icons.last_page_rounded, size: 20),
                onPressed: _currentPage < _totalPages
                    ? () => _goToPage(_totalPages)
                    : null,
                splashRadius: 18,
              ),
            ],
          ),
          Row(
            children: [
              const Text('Rows per page: ',
                  style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B))),
              DropdownButtonHideUnderline(
                child: AppSearchableDropdown<int>.fromMenuItems(
                  value: _pageSize,
                  items: const [
                    DropdownMenuItem(value: 10, child: Text('10')),
                    DropdownMenuItem(value: 25, child: Text('25')),
                    DropdownMenuItem(value: 50, child: Text('50')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _pageSize = val;
                        _currentPage = 1;
                      });
                      _loadExamsTable();
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _goToPage(int page) {
    setState(() => _currentPage = page);
    _loadExamsTable();
  }

  // ============================================================================
  // 6. BOTTOM ANALYTICS (EXAM PERFORMANCE BAR CHART, TOP PERFORMERS & RECENT ACTIVITY)
  // ============================================================================

  Widget _buildBottomAnalyticsRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 1050;
        final isMedium =
            constraints.maxWidth >= 650 && constraints.maxWidth < 1050;

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 50, child: _buildExamPerformanceCard()),
              const SizedBox(width: 16),
              Expanded(flex: 25, child: _buildTopPerformersCard()),
              const SizedBox(width: 16),
              Expanded(flex: 25, child: _buildRecentActivityCard()),
            ],
          );
        } else if (isMedium) {
          return Column(
            children: [
              _buildExamPerformanceCard(),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _buildTopPerformersCard()),
                  const SizedBox(width: 16),
                  Expanded(child: _buildRecentActivityCard()),
                ],
              ),
            ],
          );
        }

        return Column(
          children: [
            _buildExamPerformanceCard(),
            const SizedBox(height: 16),
            _buildTopPerformersCard(),
            const SizedBox(height: 16),
            _buildRecentActivityCard(),
          ],
        );
      },
    );
  }

  Widget _buildExamPerformanceCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: _isDark ? 0.2 : 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.insert_chart_outlined_rounded,
                      color: Color(0xFF2563EB), size: 18),
                  const SizedBox(width: 8),
                  Text('Exam Performance',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary)),
                ],
              ),
              Row(
                children: [
                  _buildLegendIndicator(
                      color: const Color(0xFF2563EB), label: 'Pass %'),
                  const SizedBox(width: 12),
                  _buildLegendIndicator(
                      color: const Color(0xFFC084FC), label: 'Fail %'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Custom Bar Chart representation matching UI
          SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Y-axis labels
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('100%',
                        style: TextStyle(fontSize: 9.5, color: _textSecondary)),
                    Text('75%',
                        style: TextStyle(fontSize: 9.5, color: _textSecondary)),
                    Text('50%',
                        style: TextStyle(fontSize: 9.5, color: _textSecondary)),
                    Text('25%',
                        style: TextStyle(fontSize: 9.5, color: _textSecondary)),
                    Text('0%',
                        style: TextStyle(fontSize: 9.5, color: _textSecondary)),
                  ],
                ),
                const SizedBox(width: 10),
                VerticalDivider(width: 1, color: _cardBorder),
                const SizedBox(width: 10),
                // Monthly bars
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: _performanceChart.map((m) {
                      final passPct = (m['pass_pct'] as num? ?? 85).toDouble();
                      final failPct = (m['fail_pct'] as num? ?? 15).toDouble();
                      final monthName = m['month']?.toString() ?? 'Aug';

                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                width: 10,
                                height: 120 * (passPct / 100),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2563EB),
                                  borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(3)),
                                ),
                              ),
                              const SizedBox(width: 3),
                              Container(
                                width: 10,
                                height: 120 * (failPct / 100),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFC084FC),
                                  borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(3)),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(monthName,
                              style: TextStyle(
                                  fontSize: 10.5,
                                  color: _textSecondary,
                                  fontWeight: FontWeight.w500)),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendIndicator({required Color color, required String label}) {
    return Row(
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 11,
                color: _textSecondary,
                fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildTopPerformersCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: _isDark ? 0.2 : 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.emoji_events_rounded,
                      color: Color(0xFFEAB308), size: 18),
                  const SizedBox(width: 8),
                  Text('Top Performers',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary)),
                ],
              ),
              InkWell(
                onTap: () {
                  if (_exams.isNotEmpty) _openResultsDialog(_exams.first);
                },
                child: const Text('View All →',
                    style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(_topPerformers.length, (idx) {
            final p = _topPerformers[idx];
            final rank = idx + 1;
            Color medalColor = const Color(0xFFEAB308); // Gold
            if (rank == 2) medalColor = const Color(0xFF94A3B8); // Silver
            if (rank == 3) medalColor = const Color(0xFFD97706); // Bronze

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _innerCardBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _cardBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                        color: medalColor.withValues(alpha: 0.18),
                        shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text('$rank',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: medalColor)),
                  ),
                  const SizedBox(width: 12),
                  CircleAvatar(
                    radius: 16,
                    backgroundColor:
                        const Color(0xFF2563EB).withValues(alpha: 0.2),
                    child: Text(
                      (p['name']?.toString() ?? 'S')[0],
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2563EB)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p['name'] ?? 'Student',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _textPrimary)),
                        Text(
                            '${p['class'] ?? 'Class 10'} • ${p['score_pct'] ?? 98.0}%',
                            style:
                                TextStyle(fontSize: 11, color: _textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ============================================================================
  // 7. RIGHT COLUMN CARDS (CALENDAR, QUICK ACTIONS, RECENT ACTIVITIES)
  // ============================================================================

  Widget _buildExamCalendarCard() {
    final year = _currentCalendarMonth.year;
    final month = _currentCalendarMonth.month;
    final monthName = _monthName(month);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final firstWeekday = DateTime(year, month, 1).weekday % 7; // Sunday=0

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: _isDark ? 0.2 : 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Exam Calendar',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary)),
              InkWell(
                onTap: () {
                  try {
                    context.go('/admin/calendar');
                  } catch (_) {}
                },
                child: const Text('View All →',
                    style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Month navigator
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left_rounded,
                    size: 20, color: _textSecondary),
                onPressed: () {
                  setState(
                      () => _currentCalendarMonth = DateTime(year, month - 1));
                },
                splashRadius: 16,
              ),
              Text(
                '$monthName $year',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right_rounded,
                    size: 20, color: _textSecondary),
                onPressed: () {
                  setState(
                      () => _currentCalendarMonth = DateTime(year, month + 1));
                },
                splashRadius: 16,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Day initials
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Text('Sun',
                  style: TextStyle(
                      fontSize: 10,
                      color: _textSecondary,
                      fontWeight: FontWeight.w600)),
              Text('Mon',
                  style: TextStyle(
                      fontSize: 10,
                      color: _textSecondary,
                      fontWeight: FontWeight.w600)),
              Text('Tue',
                  style: TextStyle(
                      fontSize: 10,
                      color: _textSecondary,
                      fontWeight: FontWeight.w600)),
              Text('Wed',
                  style: TextStyle(
                      fontSize: 10,
                      color: _textSecondary,
                      fontWeight: FontWeight.w600)),
              Text('Thu',
                  style: TextStyle(
                      fontSize: 10,
                      color: _textSecondary,
                      fontWeight: FontWeight.w600)),
              Text('Fri',
                  style: TextStyle(
                      fontSize: 10,
                      color: _textSecondary,
                      fontWeight: FontWeight.w600)),
              Text('Sat',
                  style: TextStyle(
                      fontSize: 10,
                      color: _textSecondary,
                      fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          // Days Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: firstWeekday + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
              childAspectRatio: 1.0,
            ),
            itemBuilder: (context, index) {
              if (index < firstWeekday) return const SizedBox();
              final dayNum = index - firstWeekday + 1;
              final isFlagshipDay =
                  dayNum == 15; // Highlighted 15th matching image
              final isOtherExamDay =
                  _highlightedCalendarDays.contains(dayNum) && !isFlagshipDay;

              return Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isFlagshipDay
                      ? const Color(0xFF2563EB)
                      : (isOtherExamDay
                          ? const Color(0xFF2563EB).withValues(alpha: 0.15)
                          : Colors.transparent),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$dayNum',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        isFlagshipDay ? FontWeight.w700 : FontWeight.w500,
                    color: isFlagshipDay
                        ? Colors.white
                        : (isOtherExamDay
                            ? const Color(0xFF2563EB)
                            : _textPrimary),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: _isDark ? 0.2 : 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Actions',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary)),
          const SizedBox(height: 12),
          _buildQuickActionItem(
            icon: Icons.calendar_today_rounded,
            iconColor: const Color(0xFF2563EB),
            label: 'Create Exam',
            onTap: () => _openCreateExamDialog(context),
          ),
          _buildQuickActionItem(
            icon: Icons.quiz_outlined,
            iconColor: const Color(0xFF16A34A),
            label: 'Add Question',
            onTap: () {
              final base = getExamsBaseRoute(context);
              context.go('$base/question-bank');
            },
          ),
          _buildQuickActionItem(
            icon: Icons.monitor_heart_rounded,
            iconColor: const Color(0xFF0D9488),
            label: 'Live Exam Monitoring',
            onTap: () {
              if (_exams.isNotEmpty) {
                final onlineExam = _exams.firstWhere(
                  (e) =>
                      (e['exam_mode'] ?? e['exam_type'] ?? '')
                          .toString()
                          .toLowerCase() ==
                      'online',
                  orElse: () => _exams.first,
                );
                final base = getExamsBaseRoute(context);
                context.go('$base/monitor/${onlineExam['id']}');
              }
            },
          ),
          _buildQuickActionItem(
            icon: Icons.published_with_changes_rounded,
            iconColor: const Color(0xFFEA580C),
            label: 'Publish Result',
            onTap: () {
              if (_exams.isNotEmpty) _openResultsDialog(_exams.first);
            },
          ),
          _buildQuickActionItem(
            icon: Icons.analytics_outlined,
            iconColor: const Color(0xFF9333EA),
            label: 'View Results',
            onTap: () {
              if (_exams.isNotEmpty) _openResultsDialog(_exams.first);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary)),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivityCard() {
    final activities = _recentActivities.isNotEmpty
        ? _recentActivities
        : [
            {
              'title': 'Mid Term Results Published',
              'description': 'Class 9 • 01 Mar 2026, 04:30 PM',
              'icon': 'check_circle',
              'color': 'green'
            },
            {
              'title': 'Annual Exam Scheduled',
              'description': 'Class 10 • 01 Mar 2026, 11:20 AM',
              'icon': 'calendar_today',
              'color': 'blue'
            },
            {
              'title': 'Question Paper Uploaded',
              'description': 'Class 12 • 28 Feb 2026, 05:15 PM',
              'icon': 'description',
              'color': 'purple'
            },
          ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cardBorder),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: _isDark ? 0.2 : 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Recent Activity',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: _textPrimary)),
              InkWell(
                onTap: () {
                  try {
                    context.go('/admin/calendar');
                  } catch (_) {}
                },
                child: const Text('View All →',
                    style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF2563EB),
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...activities.map((act) {
            Color dotColor = const Color(0xFF16A34A);
            IconData iconData = Icons.check_circle_outline_rounded;
            if (act['color'] == 'blue') {
              dotColor = const Color(0xFF2563EB);
              iconData = Icons.calendar_today_rounded;
            } else if (act['color'] == 'purple') {
              dotColor = const Color(0xFF9333EA);
              iconData = Icons.description_outlined;
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: dotColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(iconData, size: 14, color: dotColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(act['title'] ?? 'Activity',
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: _textPrimary)),
                        const SizedBox(height: 2),
                        Text(act['description'] ?? '',
                            style:
                                TextStyle(fontSize: 11, color: _textSecondary)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ============================================================================
  // 8. POPUPS & DIALOGS (CREATE / EDIT, SCHEDULE, MARKS, RESULTS)
  // ============================================================================

  void _openCreateExamDialog(BuildContext context) {
    _showExamFormDialog(context, exam: null);
  }

  void _openEditExamDialog(Map<String, dynamic> exam) {
    _showExamFormDialog(context, exam: exam);
  }

  void _showExamFormDialog(BuildContext context, {Map<String, dynamic>? exam}) {
    final isEdit = exam != null;
    final titleController = TextEditingController(text: exam?['title'] ?? '');
    final codeController =
        TextEditingController(text: exam?['exam_code'] ?? 'EXAM-2026-001');
    final durationController =
        TextEditingController(text: '${exam?['duration_minutes'] ?? 120}');
    final marksController =
        TextEditingController(text: '${exam?['total_marks'] ?? 100}');
    final passingController =
        TextEditingController(text: '${exam?['passing_marks'] ?? 33}');
    final instructionsController = TextEditingController(
        text: exam?['instructions'] ??
            '1. All questions are compulsory.\n2. Write clearly and legibly.\n3. Verify question count before beginning.');
    final userSearchController = TextEditingController();

    // 1. Dynamic Academic Sessions from Lookup Key-Value table
    final sessionOptions = _academicSessionLookups.isNotEmpty
        ? _academicSessionLookups
            .map((s) => s.name.trim())
            .where((n) => n.isNotEmpty)
            .toSet()
            .toList()
        : ['2025-26', '2024-25', '2026-27'];
    String selectedSession = exam?['academic_session'] ?? '2025-26';
    if (!sessionOptions.contains(selectedSession)) {
      sessionOptions.insert(0, selectedSession);
    }

    // 2. Dynamic Exam Categories from Lookup Key-Value table
    final categoryOptions = _examCategoryLookups.isNotEmpty
        ? _examCategoryLookups
            .map((c) => c.name.trim())
            .where((n) => n.isNotEmpty)
            .toSet()
            .toList()
        : [
            'Final Exam',
            'Mid Term',
            'Unit Test',
            'Pre Board',
            'Quarterly',
            'Annual Examination'
          ];
    String selectedCategory =
        exam?['type'] ?? exam?['exam_category'] ?? 'Final Exam';
    if (!categoryOptions.contains(selectedCategory)) {
      categoryOptions.insert(0, selectedCategory);
    }

    // 3. Dynamic Exam Modes
    final modeOptions = _examModeLookups.isNotEmpty
        ? _examModeLookups
        : const [
            QuestionBankLookupItem(code: 'offline', name: 'Offline / Paper'),
            QuestionBankLookupItem(code: 'online', name: 'Online / CBT'),
            QuestionBankLookupItem(code: 'hybrid', name: 'Hybrid'),
          ];
    String selectedMode =
        (exam?['exam_mode'] ?? exam?['exam_type'] ?? 'offline')
            .toString()
            .toLowerCase()
            .trim();
    if (!modeOptions.any((m) => m.code.toLowerCase().trim() == selectedMode)) {
      selectedMode = modeOptions.first.code.toLowerCase().trim();
    }

    // 4. Status Options
    final statusOptions = [
      'Scheduled',
      'Ongoing',
      'Completed',
      'Draft',
      'Cancelled'
    ];
    String currentRawStatus = (exam?['status'] ?? 'Scheduled').toString();
    String selectedStatus = statusOptions.firstWhere(
      (s) => s.toLowerCase() == currentRawStatus.toLowerCase(),
      orElse: () => 'Scheduled',
    );

    // 5. Date & Time
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));
    if (exam?['exam_date'] != null) {
      selectedDate =
          DateTime.tryParse(exam!['exam_date'].toString()) ?? selectedDate;
    } else if (exam?['start_time'] != null) {
      try {
        selectedDate = DateTime.parse(exam!['start_time'].toString());
      } catch (_) {}
    }

    TimeOfDay selectedTime = const TimeOfDay(hour: 9, minute: 0);
    if (exam?['start_time'] != null) {
      try {
        final rawSt = exam!['start_time'].toString();
        if (rawSt.contains('T')) {
          final dt = DateTime.parse(rawSt);
          selectedTime = TimeOfDay(hour: dt.hour, minute: dt.minute);
        } else if (rawSt.contains(':')) {
          final parts = rawSt.split(':');
          final h = int.tryParse(parts[0]) ?? 9;
          final m = parts.length > 1
              ? (int.tryParse(parts[1].split(' ')[0]) ?? 0)
              : 0;
          final isPm = rawSt.toLowerCase().contains('pm') && h < 12;
          selectedTime = TimeOfDay(hour: isPm ? h + 12 : h, minute: m);
        }
      } catch (_) {}
    }

    // 6. Multiselect Classes (sourced dynamically from Class Management SSOT)
    final Set<String> selectedClasses = {};
    if (exam?['target_classes'] is List) {
      for (final c in exam!['target_classes'] as List) {
        if (c is String && c.trim().isNotEmpty) selectedClasses.add(c.trim());
        if (c is Map && c['name'] != null) {
          selectedClasses.add(c['name'].toString().trim());
        }
      }
    } else if (exam?['class'] != null &&
        exam!['class'].toString().trim().isNotEmpty &&
        exam['class'] != 'General') {
      selectedClasses.add(exam['class'].toString().trim());
    }

    // 7. Multiselect Sections (sourced dynamically from Class Management SSOT)
    final Set<String> selectedSections = {};
    if (exam?['applicable_sections'] is List) {
      for (final s in exam!['applicable_sections'] as List) {
        if (s is String && s.trim().isNotEmpty) selectedSections.add(s.trim());
        if (s is Map && s['name'] != null) {
          selectedSections.add(s['name'].toString().trim());
        }
      }
    }

    // 8. Targeted Users (students, staff, teachers, new joiners)
    List<Map<String, dynamic>> selectedTargetUsers = [];
    final List<String> initialTargetUserIds = [];
    if (exam?['target_students'] is List) {
      for (final u in exam!['target_students'] as List) {
        if (u is String && u.trim().isNotEmpty) {
          initialTargetUserIds.add(u.trim());
        }
        if (u is Map && (u['id'] != null || u['candidate_id'] != null)) {
          initialTargetUserIds
              .add((u['id'] ?? u['candidate_id']).toString().trim());
        }
      }
    }

    List<Map<String, dynamic>> userSearchResults = [];
    bool isSearchingUsers = false;
    bool hasInitializedUsers = false;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // Asynchronously pre-load profile cards for existing target_students
          if (!hasInitializedUsers) {
            hasInitializedUsers = true;
            if (initialTargetUserIds.isNotEmpty) {
              _apiService
                  .getExamTargetUsersBatch(initialTargetUserIds)
                  .then((profiles) {
                if (profiles.isNotEmpty) {
                  setDialogState(() {
                    selectedTargetUsers =
                        List<Map<String, dynamic>>.from(profiles);
                  });
                }
              }).catchError((_) {});
            }
          }

          // Build dynamic list of classes from Class Management SSOT
          final List<String> availableClassNames = [];
          if (_classesWithSections.isNotEmpty) {
            for (final cm in _classesWithSections) {
              final cname = cm['name']?.toString().trim();
              if (cname != null &&
                  cname.isNotEmpty &&
                  !availableClassNames.contains(cname)) {
                availableClassNames.add(cname);
              }
            }
          } else {
            availableClassNames.addAll(
              _classList
                  .where((c) => c != 'All Classes' && c.trim().isNotEmpty)
                  .toSet(),
            );
          }

          // Build dynamic list of sections matching selected classes from Class Management SSOT
          final List<Map<String, dynamic>> availableSections = [];
          for (final cm in _classesWithSections) {
            final cname = cm['name']?.toString().trim() ?? '';
            if (selectedClasses.isEmpty || selectedClasses.contains(cname)) {
              final secs = cm['sections'] as List? ?? [];
              for (final s in secs) {
                if (s is Map) {
                  final sname = s['name']?.toString().trim() ?? '';
                  final disp =
                      s['display_name']?.toString().trim() ?? '$cname - $sname';
                  if (sname.isNotEmpty) {
                    availableSections.add({
                      'name': sname,
                      'class_name': cname,
                      'display_name': disp,
                    });
                  }
                }
              }
            }
          }

          return Dialog(
            backgroundColor: _cardBg,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: _cardBorder),
            ),
            child: Container(
              width: 720,
              constraints: const BoxConstraints(maxHeight: 780),
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dialog Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2563EB)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.school_rounded,
                                  color: Color(0xFF2563EB), size: 20),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              isEdit
                                  ? 'Edit Examination'
                                  : 'Create Examination',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: _textPrimary),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded,
                              size: 20, color: _textSecondary),
                          onPressed: () => Navigator.of(ctx).pop(),
                        ),
                      ],
                    ),
                    Divider(height: 24, color: _cardBorder),

                    // Title & Exam Code
                    Row(
                      children: [
                        Expanded(
                          flex: 65,
                          child: _buildFormField(
                              'Examination Title *',
                              titleController,
                              'e.g. Annual Examination 2025-26'),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          flex: 35,
                          child: _buildFormField(
                              'Exam Code', codeController, 'e.g. EXAM-10-ANN'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Session, Mode, Category
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Academic Session',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _textPrimary)),
                              const SizedBox(height: 6),
                              Container(
                                height: 40,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: _inputBg,
                                  border: Border.all(color: _cardBorder),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: AppSearchableDropdown<String>.fromMenuItems(
                                    isExpanded: true,
                                    dropdownColor: _cardBg,
                                    value:
                                        sessionOptions.contains(selectedSession)
                                            ? selectedSession
                                            : sessionOptions.first,
                                    items: sessionOptions
                                        .map((s) => DropdownMenuItem(
                                            value: s,
                                            child: Text(s,
                                                style: TextStyle(
                                                    color: _textPrimary,
                                                    fontSize: 13))))
                                        .toList(),
                                    onChanged: (v) => setDialogState(() =>
                                        selectedSession =
                                            v ?? sessionOptions.first),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Exam Category',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _textPrimary)),
                              const SizedBox(height: 6),
                              Container(
                                height: 40,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: _inputBg,
                                  border: Border.all(color: _cardBorder),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: AppSearchableDropdown<String>.fromMenuItems(
                                    isExpanded: true,
                                    dropdownColor: _cardBg,
                                    value: categoryOptions
                                            .contains(selectedCategory)
                                        ? selectedCategory
                                        : categoryOptions.first,
                                    items: categoryOptions
                                        .map((t) => DropdownMenuItem(
                                            value: t,
                                            child: Text(t,
                                                style: TextStyle(
                                                    color: _textPrimary,
                                                    fontSize: 13))))
                                        .toList(),
                                    onChanged: (v) => setDialogState(() =>
                                        selectedCategory =
                                            v ?? categoryOptions.first),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Exam Mode',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _textPrimary)),
                              const SizedBox(height: 6),
                              Container(
                                height: 40,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: _inputBg,
                                  border: Border.all(color: _cardBorder),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: AppSearchableDropdown<String>.fromMenuItems(
                                    isExpanded: true,
                                    dropdownColor: _cardBg,
                                    value: modeOptions.any((m) =>
                                            m.code.toLowerCase().trim() ==
                                            selectedMode)
                                        ? selectedMode
                                        : modeOptions.first.code
                                            .toLowerCase()
                                            .trim(),
                                    items: modeOptions
                                        .map((m) => DropdownMenuItem(
                                              value:
                                                  m.code.toLowerCase().trim(),
                                              child: Text(m.name,
                                                  style: TextStyle(
                                                      color: _textPrimary,
                                                      fontSize: 13)),
                                            ))
                                        .toList(),
                                    onChanged: (v) => setDialogState(
                                        () => selectedMode = v ?? 'offline'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // 1. CLASS MANAGEMENT SSOT: MULTISELECT CLASSES (OPTIONAL)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _innerCardBg,
                        border: Border.all(color: _cardBorder),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.class_outlined,
                                      size: 16, color: Color(0xFF2563EB)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Target Classes (Class Management)',
                                    style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: _textPrimary),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _textSecondary.withValues(
                                          alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text('Optional • Multiselect',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: _textSecondary)),
                                  ),
                                ],
                              ),
                              if (selectedClasses.isNotEmpty)
                                TextButton(
                                  onPressed: () => setDialogState(
                                      () => selectedClasses.clear()),
                                  style: TextButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero),
                                  child: const Text('Clear All',
                                      style: TextStyle(
                                          fontSize: 11.5,
                                          color: Colors.redAccent)),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: availableClassNames.map((cName) {
                              final isSelected =
                                  selectedClasses.contains(cName);
                              return FilterChip(
                                label: Text(cName,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: isSelected
                                            ? Colors.white
                                            : _textPrimary,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500)),
                                selected: isSelected,
                                selectedColor: const Color(0xFF2563EB),
                                backgroundColor: _inputBg,
                                checkmarkColor: Colors.white,
                                side: BorderSide(
                                    color: isSelected
                                        ? const Color(0xFF2563EB)
                                        : _cardBorder),
                                onSelected: (sel) {
                                  setDialogState(() {
                                    if (sel) {
                                      selectedClasses.add(cName);
                                    } else {
                                      selectedClasses.remove(cName);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // 2. CLASS MANAGEMENT SSOT: MULTISELECT SECTIONS (OPTIONAL)
                    if (availableSections.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _innerCardBg,
                          border: Border.all(color: _cardBorder),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.meeting_room_outlined,
                                        size: 16, color: Color(0xFF2563EB)),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Applicable Sections (Class Management)',
                                      style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: _textPrimary),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _textSecondary.withValues(
                                            alpha: 0.12),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text('Optional • Multiselect',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: _textSecondary)),
                                    ),
                                  ],
                                ),
                                if (selectedSections.isNotEmpty)
                                  TextButton(
                                    onPressed: () => setDialogState(
                                        () => selectedSections.clear()),
                                    style: TextButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        padding: EdgeInsets.zero),
                                    child: const Text('Clear All',
                                        style: TextStyle(
                                            fontSize: 11.5,
                                            color: Colors.redAccent)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: availableSections.map((sec) {
                                final sname = sec['name']?.toString() ?? '';
                                final isSelected =
                                    selectedSections.contains(sname);
                                return FilterChip(
                                  label: Text(
                                    sec['display_name']?.toString() ?? sname,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: isSelected
                                            ? Colors.white
                                            : _textPrimary,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500),
                                  ),
                                  selected: isSelected,
                                  selectedColor: const Color(0xFF0D9488),
                                  backgroundColor: _inputBg,
                                  checkmarkColor: Colors.white,
                                  side: BorderSide(
                                      color: isSelected
                                          ? const Color(0xFF0D9488)
                                          : _cardBorder),
                                  onSelected: (sel) {
                                    setDialogState(() {
                                      if (sel) {
                                        selectedSections.add(sname);
                                      } else {
                                        selectedSections.remove(sname);
                                      }
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // 3. TARGET SPECIFIC USERS SEARCH & MULTISELECT (STUDENTS / STAFF / TEACHERS)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _innerCardBg,
                        border: Border.all(color: _cardBorder),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.person_search_rounded,
                                  size: 16, color: Color(0xFF2563EB)),
                              const SizedBox(width: 6),
                              Text(
                                'Target Specific Users (User Management)',
                                style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: _textPrimary),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _textSecondary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                    'Students • Staff • Teachers • New Joiners',
                                    style: TextStyle(
                                        fontSize: 10, color: _textSecondary)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: userSearchController,
                                  style: TextStyle(
                                      color: _textPrimary, fontSize: 13),
                                  decoration: InputDecoration(
                                    hintText:
                                        'Search by user name, email or roll number...',
                                    hintStyle: TextStyle(
                                        color: _textSecondary, fontSize: 12.5),
                                    filled: true,
                                    fillColor: _inputBg,
                                    prefixIcon: Icon(Icons.search,
                                        size: 16, color: _textSecondary),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide:
                                            BorderSide(color: _cardBorder)),
                                    enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide:
                                            BorderSide(color: _cardBorder)),
                                  ),
                                  onSubmitted: (val) async {
                                    final q = val.trim();
                                    if (q.isEmpty) return;
                                    setDialogState(
                                        () => isSearchingUsers = true);
                                    try {
                                      final res = await _apiService
                                          .searchExamTargetUsers(q);
                                      setDialogState(() {
                                        userSearchResults = res;
                                        isSearchingUsers = false;
                                      });
                                    } catch (_) {
                                      setDialogState(
                                          () => isSearchingUsers = false);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton.icon(
                                onPressed: isSearchingUsers
                                    ? null
                                    : () async {
                                        final q =
                                            userSearchController.text.trim();
                                        if (q.isEmpty) return;
                                        setDialogState(
                                            () => isSearchingUsers = true);
                                        try {
                                          final res = await _apiService
                                              .searchExamTargetUsers(q);
                                          setDialogState(() {
                                            userSearchResults = res;
                                            isSearchingUsers = false;
                                          });
                                        } catch (_) {
                                          setDialogState(
                                              () => isSearchingUsers = false);
                                        }
                                      },
                                icon: isSearchingUsers
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white))
                                    : const Icon(Icons.search, size: 16),
                                label: const Text('Search'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2563EB),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                          if (userSearchResults.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Container(
                              constraints: const BoxConstraints(maxHeight: 140),
                              decoration: BoxDecoration(
                                color: _inputBg,
                                border: Border.all(color: _cardBorder),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                itemCount: userSearchResults.length,
                                separatorBuilder: (_, __) =>
                                    Divider(height: 1, color: _cardBorder),
                                itemBuilder: (context, idx) {
                                  final u = userSearchResults[idx];
                                  final uid = (u['id'] ?? u['user_id'] ?? '')
                                      .toString();
                                  final isAlreadyAdded =
                                      selectedTargetUsers.any((x) =>
                                          (x['id'] ?? x['user_id'] ?? '')
                                              .toString() ==
                                          uid);
                                  return ListTile(
                                    dense: true,
                                    visualDensity: VisualDensity.compact,
                                    leading: CircleAvatar(
                                      radius: 12,
                                      backgroundColor: const Color(0xFF2563EB),
                                      child: Text(
                                        (u['full_name'] ?? 'U')
                                            .toString()
                                            .substring(0, 1)
                                            .toUpperCase(),
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    title: Text(
                                        '${u['full_name'] ?? 'User'} (${u['role'] ?? 'user'})',
                                        style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w600,
                                            color: _textPrimary)),
                                    subtitle: Text(
                                        u['email'] ?? u['roll_number'] ?? '',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: _textSecondary)),
                                    trailing: isAlreadyAdded
                                        ? const Icon(Icons.check_circle_rounded,
                                            size: 18, color: Color(0xFF16A34A))
                                        : IconButton(
                                            icon: const Icon(
                                                Icons
                                                    .add_circle_outline_rounded,
                                                size: 18,
                                                color: Color(0xFF2563EB)),
                                            onPressed: () {
                                              setDialogState(() {
                                                selectedTargetUsers.add(u);
                                                userSearchResults.removeAt(idx);
                                              });
                                            },
                                          ),
                                  );
                                },
                              ),
                            ),
                          ],
                          if (selectedTargetUsers.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: selectedTargetUsers.map((u) {
                                final uid =
                                    (u['id'] ?? u['user_id'] ?? '').toString();
                                return Chip(
                                  backgroundColor: const Color(0xFF6366F1)
                                      .withValues(alpha: 0.15),
                                  side: const BorderSide(
                                      color: Color(0xFF6366F1)),
                                  avatar: CircleAvatar(
                                    radius: 10,
                                    backgroundColor: const Color(0xFF6366F1),
                                    child: Text(
                                      (u['full_name'] ?? 'U')
                                          .toString()
                                          .substring(0, 1)
                                          .toUpperCase(),
                                      style: const TextStyle(
                                          fontSize: 9,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  label: Text(
                                      '${u['full_name'] ?? 'User'} (${u['role'] ?? 'user'})',
                                      style: TextStyle(
                                          fontSize: 11.5,
                                          color: _textPrimary,
                                          fontWeight: FontWeight.w600)),
                                  deleteIcon: const Icon(Icons.close, size: 14),
                                  onDeleted: () {
                                    setDialogState(() {
                                      selectedTargetUsers.removeWhere((x) =>
                                          (x['id'] ?? x['user_id'] ?? '')
                                              .toString() ==
                                          uid);
                                    });
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Date, Start Time & Status
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Exam Date',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _textPrimary)),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () async {
                                  final d = await showDatePicker(
                                    context: context,
                                    initialDate: selectedDate,
                                    firstDate: DateTime.now()
                                        .subtract(const Duration(days: 365)),
                                    lastDate: DateTime.now()
                                        .add(const Duration(days: 365)),
                                  );
                                  if (d != null) {
                                    setDialogState(() => selectedDate = d);
                                  }
                                },
                                child: Container(
                                  height: 40,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: _inputBg,
                                    border: Border.all(color: _cardBorder),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                          '${selectedDate.day} ${_monthName(selectedDate.month)} ${selectedDate.year}',
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: _textPrimary)),
                                      Icon(Icons.calendar_month_outlined,
                                          size: 16, color: _textSecondary),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Start Time',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _textPrimary)),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () async {
                                  final t = await showTimePicker(
                                      context: context,
                                      initialTime: selectedTime);
                                  if (t != null) {
                                    setDialogState(() => selectedTime = t);
                                  }
                                },
                                child: Container(
                                  height: 40,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: _inputBg,
                                    border: Border.all(color: _cardBorder),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(selectedTime.format(context),
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: _textPrimary)),
                                      Icon(Icons.access_time_rounded,
                                          size: 16, color: _textSecondary),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Examination Status',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: _textPrimary)),
                              const SizedBox(height: 6),
                              Container(
                                height: 40,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                decoration: BoxDecoration(
                                  color: _inputBg,
                                  border: Border.all(color: _cardBorder),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: AppSearchableDropdown<String>.fromMenuItems(
                                    isExpanded: true,
                                    dropdownColor: _cardBg,
                                    value:
                                        statusOptions.contains(selectedStatus)
                                            ? selectedStatus
                                            : statusOptions.first,
                                    items: statusOptions
                                        .map((st) => DropdownMenuItem(
                                            value: st,
                                            child: Text(st,
                                                style: TextStyle(
                                                    color: _textPrimary,
                                                    fontSize: 13))))
                                        .toList(),
                                    onChanged: (v) => setDialogState(() =>
                                        selectedStatus =
                                            v ?? statusOptions.first),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Total Marks, Passing Marks, Duration
                    Row(
                      children: [
                        Expanded(
                            child: _buildFormField(
                                'Total Marks', marksController, '100',
                                isNumber: true)),
                        const SizedBox(width: 14),
                        Expanded(
                            child: _buildFormField(
                                'Passing Marks', passingController, '33',
                                isNumber: true)),
                        const SizedBox(width: 14),
                        Expanded(
                            child: _buildFormField(
                                'Duration (Mins)', durationController, '120',
                                isNumber: true)),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Instructions
                    _buildFormField('Examination Instructions',
                        instructionsController, 'Instructions for students...',
                        maxLines: 3),
                    const SizedBox(height: 24),

                    // Dialog Actions
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _textSecondary,
                            side: BorderSide(color: _cardBorder),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  if (titleController.text.trim().isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Please enter an exam title')));
                                    return;
                                  }

                                  setDialogState(() => isSubmitting = true);

                                  final startIso = DateTime(
                                    selectedDate.year,
                                    selectedDate.month,
                                    selectedDate.day,
                                    selectedTime.hour,
                                    selectedTime.minute,
                                  ).toIso8601String();

                                  final targetUserIds = selectedTargetUsers
                                      .map((u) => (u['id'] ??
                                              u['user_id'] ??
                                              u['candidate_id'])
                                          ?.toString())
                                      .where(
                                          (id) => id != null && id.isNotEmpty)
                                      .cast<String>()
                                      .toList();

                                  final payload = {
                                    'title': titleController.text.trim(),
                                    'exam_code': codeController.text.trim(),
                                    'academic_session': selectedSession,
                                    'exam_mode': selectedMode,
                                    'type': selectedCategory,
                                    'exam_category': selectedCategory,
                                    'target_classes': selectedClasses.toList(),
                                    'class': selectedClasses.isNotEmpty
                                        ? selectedClasses.first
                                        : 'General',
                                    'applicable_sections':
                                        selectedSections.toList(),
                                    'target_students': targetUserIds,
                                    'exam_date': selectedDate
                                        .toIso8601String()
                                        .split('T')[0],
                                    'start_time': startIso,
                                    'duration_minutes':
                                        int.tryParse(durationController.text) ??
                                            120,
                                    'total_marks':
                                        int.tryParse(marksController.text) ??
                                            100,
                                    'passing_marks':
                                        int.tryParse(passingController.text) ??
                                            33,
                                    'instructions':
                                        instructionsController.text.trim(),
                                    'status': selectedStatus.toLowerCase(),
                                  };

                                  try {
                                    if (isEdit) {
                                      await _apiService.updateExam(
                                          exam['id'], payload);
                                    } else {
                                      await _apiService.createExam(
                                        title: payload['title'] as String,
                                        subject: 'Mathematics',
                                        targetClasses: selectedClasses.toList(),
                                        applicableSections:
                                            selectedSections.toList(),
                                        targetStudents: targetUserIds,
                                        startTime: DateTime(
                                          selectedDate.year,
                                          selectedDate.month,
                                          selectedDate.day,
                                          selectedTime.hour,
                                          selectedTime.minute,
                                        ),
                                        examDate: selectedDate,
                                        duration:
                                            '${payload['duration_minutes']} mins',
                                        totalMarks:
                                            payload['total_marks'] as int,
                                        examType: selectedMode,
                                        examCategory: selectedCategory,
                                        instructions:
                                            instructionsController.text.trim(),
                                        status: selectedStatus.toLowerCase(),
                                      );
                                    }
                                    if (ctx.mounted) Navigator.of(ctx).pop();
                                    _loadDashboardOverview();
                                    _loadExamsTable();
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                        content: Text(isEdit
                                            ? 'Examination updated successfully'
                                            : 'Examination scheduled successfully'),
                                        backgroundColor:
                                            const Color(0xFF16A34A),
                                      ));
                                    }
                                  } catch (e) {
                                    setDialogState(() => isSubmitting = false);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(
                                        content: Text(
                                            'Failed: ${e.toString().replaceFirst("Exception: ", "")}'),
                                        backgroundColor: Colors.red,
                                      ));
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8)),
                          ),
                          child: isSubmitting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : Text(isEdit
                                  ? 'Save Changes'
                                  : 'Schedule Examination'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFormField(
      String label, TextEditingController controller, String hint,
      {bool isNumber = false, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _textPrimary)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          maxLines: maxLines,
          style: TextStyle(fontSize: 13, color: _textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: _inputBg,
            hintText: hint,
            hintStyle: TextStyle(color: _textSecondary, fontSize: 13),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: _cardBorder)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: _cardBorder)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF2563EB))),
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // 9. SCHEDULE (DATE SHEET) DIALOG WITH CONFLICT DETECTION
  // ============================================================================

  void _openScheduleDialog(Map<String, dynamic> exam) async {
    final examId = exam['id']?.toString() ?? '';
    List<Map<String, dynamic>> schedules = [];
    bool loading = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          if (loading) {
            _apiService.getExamSchedules(examId).then((res) {
              setDialogState(() {
                schedules = res;
                loading = false;
              });
            });
          }

          return Dialog(
            backgroundColor: _cardBg,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: _cardBorder),
            ),
            child: Container(
              width: 750,
              constraints: const BoxConstraints(maxHeight: 650),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Examination Date Sheet: ${exam['title']}',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: _textPrimary)),
                          const SizedBox(height: 2),
                          Text(
                              '${exam['class']} • ${exam['type']} • Academic Year 2025-26',
                              style: TextStyle(
                                  fontSize: 12.5, color: _textSecondary)),
                        ],
                      ),
                      IconButton(
                          icon: Icon(Icons.close_rounded,
                              size: 20, color: _textSecondary),
                          onPressed: () => Navigator.of(ctx).pop()),
                    ],
                  ),
                  Divider(height: 24, color: _cardBorder),
                  // Action button to add subject slot
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Subject Timetable & Venues',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _textPrimary)),
                      ElevatedButton.icon(
                        onPressed: () =>
                            _openAddScheduleSlotDialog(ctx, examId, (newSlot) {
                          setDialogState(() {
                            schedules.add(newSlot);
                          });
                        }),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Subject Slot'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Schedule Table
                  Expanded(
                    child: loading
                        ? const Center(child: CircularProgressIndicator())
                        : schedules.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.calendar_today_outlined,
                                        size: 40, color: _textSecondary),
                                    const SizedBox(height: 8),
                                    Text('No date sheet slots configured yet.',
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: _textSecondary)),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: schedules.length,
                                itemBuilder: (context, idx) {
                                  final sc = schedules[idx];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _innerCardBg,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: _cardBorder),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 36,
                                          height: 36,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2563EB)
                                                .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                              Icons.menu_book_rounded,
                                              color: Color(0xFF2563EB),
                                              size: 18),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          flex: 3,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                  sc['subject_name'] ??
                                                      'Subject',
                                                  style: TextStyle(
                                                      fontSize: 13.5,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: _textPrimary)),
                                              Text(
                                                  'Max Marks: ${sc['max_marks'] ?? 100} • Pass: ${sc['passing_marks'] ?? 33}',
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      color: _textSecondary)),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                  '${sc['exam_date']} • ${sc['start_time']}',
                                                  style: TextStyle(
                                                      fontSize: 12.5,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: _textPrimary)),
                                              Text(
                                                  'Duration: ${sc['duration_minutes'] ?? 120} mins',
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      color: _textSecondary)),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          flex: 3,
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                  sc['room_number'] ??
                                                      'Hall 101',
                                                  style: TextStyle(
                                                      fontSize: 12.5,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: _textPrimary)),
                                              Text(
                                                  'Invigilator: ${sc['invigilator_name'] ?? 'Faculty'}',
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      color: _textSecondary)),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                              Icons.delete_outline_rounded,
                                              color: Colors.red,
                                              size: 18),
                                          onPressed: () async {
                                            final sid =
                                                sc['id']?.toString() ?? '';
                                            if (sid.isNotEmpty) {
                                              await _apiService
                                                  .deleteExamSchedule(sid);
                                              setDialogState(() =>
                                                  schedules.removeAt(idx));
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openAddScheduleSlotDialog(BuildContext parentContext, String examId,
      ValueChanged<Map<String, dynamic>> onAdded) {
    final subjController = TextEditingController(text: 'Science');
    final roomController = TextEditingController(text: 'Exam Hall 102');
    final invigilatorController = TextEditingController(text: 'Prof. Verma');
    DateTime date = DateTime.now().add(const Duration(days: 10));

    showDialog(
      context: parentContext,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _cardBorder),
        ),
        title: Text('Add Date Sheet Slot',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFormField(
                'Subject Name', subjController, 'e.g. Science / Mathematics'),
            const SizedBox(height: 10),
            _buildFormField(
                'Room / Hall Number', roomController, 'e.g. Hall 102'),
            const SizedBox(height: 10),
            _buildFormField(
                'Invigilator Name', invigilatorController, 'e.g. Prof. Verma'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              final payload = {
                'subject_name': subjController.text.trim(),
                'room_number': roomController.text.trim(),
                'invigilator_name': invigilatorController.text.trim(),
                'exam_date': date.toIso8601String().split('T')[0],
                'start_time': '09:00:00',
                'end_time': '11:00:00',
                'duration_minutes': 120,
                'max_marks': 100,
                'passing_marks': 33,
              };
              final res = await _apiService.createExamSchedule(examId, payload);
              if (res['has_conflict'] == true) {
                ScaffoldMessenger.of(parentContext).showSnackBar(SnackBar(
                  content: Text(res['message'] ?? 'Schedule conflict detected'),
                  backgroundColor: Colors.amber[900],
                ));
              } else {
                onAdded(res['data'] ?? payload);
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(parentContext).showSnackBar(const SnackBar(
                    content: Text('Subject slot scheduled successfully'),
                    backgroundColor: Colors.green));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2563EB),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Save Slot'),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // 10. MARKS ENTRY MODAL (INTERACTIVE EVALUATION GRID)
  // ============================================================================

  void _openMarksEntryDialog(Map<String, dynamic> exam) async {
    final examId = exam['id']?.toString() ?? '';
    List<Map<String, dynamic>> roster = [];
    bool loading = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          if (loading) {
            _apiService.getExamMarks(examId).then((res) {
              setDialogState(() {
                roster = res;
                loading = false;
              });
            });
          }

          return Dialog(
            backgroundColor: _cardBg,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: _cardBorder),
            ),
            child: Container(
              width: 850,
              constraints: const BoxConstraints(maxHeight: 700),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Marks Entry: ${exam['title']}',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: _textPrimary)),
                          const SizedBox(height: 2),
                          Text(
                              '${exam['class']} • Total Marks: ${exam['total_marks'] ?? 100}',
                              style: TextStyle(
                                  fontSize: 12.5, color: _textSecondary)),
                        ],
                      ),
                      IconButton(
                          icon: Icon(Icons.close_rounded,
                              size: 20, color: _textSecondary),
                          onPressed: () => Navigator.of(ctx).pop()),
                    ],
                  ),
                  Divider(height: 20, color: _cardBorder),
                  // Roster Grid
                  Expanded(
                    child: loading
                        ? const Center(child: CircularProgressIndicator())
                        : SingleChildScrollView(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                              headingRowColor:
                                  WidgetStateProperty.all(_innerCardBg),
                              dividerThickness: 1,
                              columns: [
                                DataColumn(
                                    label: Text('Roll No',
                                        style: TextStyle(
                                            color: _textPrimary,
                                            fontWeight: FontWeight.w600))),
                                DataColumn(
                                    label: Text('Student Name',
                                        style: TextStyle(
                                            color: _textPrimary,
                                            fontWeight: FontWeight.w600))),
                                DataColumn(
                                    label: Text('Attendance',
                                        style: TextStyle(
                                            color: _textPrimary,
                                            fontWeight: FontWeight.w600))),
                                DataColumn(
                                    label: Text('Theory',
                                        style: TextStyle(
                                            color: _textPrimary,
                                            fontWeight: FontWeight.w600))),
                                DataColumn(
                                    label: Text('Practical',
                                        style: TextStyle(
                                            color: _textPrimary,
                                            fontWeight: FontWeight.w600))),
                                DataColumn(
                                    label: Text('Total',
                                        style: TextStyle(
                                            color: _textPrimary,
                                            fontWeight: FontWeight.w600))),
                                DataColumn(
                                    label: Text('Grade',
                                        style: TextStyle(
                                            color: _textPrimary,
                                            fontWeight: FontWeight.w600))),
                              ],
                              rows: roster.map((st) {
                                return DataRow(cells: [
                                  DataCell(Text(
                                      st['roll_number']?.toString() ?? '-',
                                      style: TextStyle(color: _textSecondary))),
                                  DataCell(Text(st['student_name'] ?? 'Student',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: _textPrimary))),
                                  DataCell(
                                    AppSearchableDropdown<String>.fromMenuItems(
                                      value:
                                          st['attendance_status'] ?? 'present',
                                      dropdownColor: _cardBg,
                                      style: TextStyle(
                                          color: _textPrimary, fontSize: 13),
                                      items: [
                                        DropdownMenuItem(
                                            value: 'present',
                                            child: Text('Present',
                                                style: TextStyle(
                                                    color: _textPrimary))),
                                        DropdownMenuItem(
                                            value: 'absent',
                                            child: Text('Absent',
                                                style: TextStyle(
                                                    color: _textPrimary))),
                                        DropdownMenuItem(
                                            value: 'medical',
                                            child: Text('Medical',
                                                style: TextStyle(
                                                    color: _textPrimary))),
                                      ],
                                      onChanged: (v) {
                                        setDialogState(
                                            () => st['attendance_status'] = v);
                                      },
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 60,
                                      child: TextFormField(
                                        initialValue:
                                            '${st['theory_marks'] ?? ''}',
                                        keyboardType: TextInputType.number,
                                        style: TextStyle(
                                            color: _textPrimary, fontSize: 13),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          filled: true,
                                          fillColor: _inputBg,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 8),
                                          border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              borderSide: BorderSide(
                                                  color: _cardBorder)),
                                          enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              borderSide: BorderSide(
                                                  color: _cardBorder)),
                                        ),
                                        onChanged: (v) {
                                          final numVal =
                                              double.tryParse(v) ?? 0;
                                          final pVal = double.tryParse(
                                                  '${st['practical_marks'] ?? 0}') ??
                                              0;
                                          st['theory_marks'] = numVal;
                                          st['total_marks_obtained'] =
                                              numVal + pVal;
                                          final pct = ((numVal + pVal) /
                                                  (st['max_marks'] ?? 100)) *
                                              100;
                                          st['percentage'] = pct;
                                          st['grade'] = _calcGrade(pct);
                                          setDialogState(() {});
                                        },
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: 60,
                                      child: TextFormField(
                                        initialValue:
                                            '${st['practical_marks'] ?? ''}',
                                        keyboardType: TextInputType.number,
                                        style: TextStyle(
                                            color: _textPrimary, fontSize: 13),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          filled: true,
                                          fillColor: _inputBg,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 8),
                                          border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              borderSide: BorderSide(
                                                  color: _cardBorder)),
                                          enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              borderSide: BorderSide(
                                                  color: _cardBorder)),
                                        ),
                                        onChanged: (v) {
                                          final pVal = double.tryParse(v) ?? 0;
                                          final tVal = double.tryParse(
                                                  '${st['theory_marks'] ?? 0}') ??
                                              0;
                                          st['practical_marks'] = pVal;
                                          st['total_marks_obtained'] =
                                              tVal + pVal;
                                          final pct = ((tVal + pVal) /
                                                  (st['max_marks'] ?? 100)) *
                                              100;
                                          st['percentage'] = pct;
                                          st['grade'] = _calcGrade(pct);
                                          setDialogState(() {});
                                        },
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(
                                      '${st['total_marks_obtained'] ?? '-'}',
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: _textPrimary))),
                                  DataCell(_buildGradePill(
                                      st['grade']?.toString() ?? '-')),
                                ]);
                              }).toList(),
                            ),
                          ),
                        ),
                  ),
                  Divider(height: 20, color: _cardBorder),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _textSecondary,
                          side: BorderSide(color: _cardBorder),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Close'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () async {
                          await _apiService.saveExamMarks(examId, roster);
                          await _apiService.calculateExamResults(examId);
                          _loadDashboardOverview();
                          _loadExamsTable();
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(
                            content: Text(
                                'Marks saved and results calculated successfully!'),
                            backgroundColor: Color(0xFF16A34A),
                          ));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Save & Calculate Results'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _calcGrade(double pct) {
    if (pct >= 91) return 'A1';
    if (pct >= 81) return 'A2';
    if (pct >= 71) return 'B1';
    if (pct >= 61) return 'B2';
    if (pct >= 51) return 'C1';
    if (pct >= 41) return 'C2';
    if (pct >= 33) return 'D';
    return 'E';
  }

  Widget _buildGradePill(String grade) {
    Color color = const Color(0xFF16A34A);
    if (grade == 'B1' || grade == 'B2') color = const Color(0xFF2563EB);
    if (grade == 'C1' || grade == 'C2') color = const Color(0xFFEA580C);
    if (grade == 'D') color = const Color(0xFFD97706);
    if (grade == 'E' || grade == 'F') color = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6)),
      child: Text(grade,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }

  // ============================================================================
  // 11. RESULTS & RANKING MODAL
  // ============================================================================

  void _openResultsDialog(Map<String, dynamic> exam) async {
    final examId = exam['id']?.toString() ?? '';
    Map<String, dynamic> resultsData = {};
    bool loading = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          if (loading) {
            _apiService.getExamResults(examId).then((res) {
              setDialogState(() {
                resultsData = res['data'] is Map
                    ? Map<String, dynamic>.from(res['data'])
                    : {};
                loading = false;
              });
            });
          }

          final studentList = (resultsData['results'] as List? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();

          return Dialog(
            backgroundColor: _cardBg,
            surfaceTintColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: _cardBorder),
            ),
            child: Container(
              width: 750,
              constraints: const BoxConstraints(maxHeight: 650),
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Examination Results: ${exam['title']}',
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: _textPrimary)),
                          const SizedBox(height: 2),
                          Text(
                              'Pass Rate: ${resultsData['pass_percentage'] ?? 96.2}% • Average: ${resultsData['average_score'] ?? 78.5}%',
                              style: TextStyle(
                                  fontSize: 12.5, color: _textSecondary)),
                        ],
                      ),
                      IconButton(
                          icon: Icon(Icons.close_rounded,
                              size: 20, color: _textSecondary),
                          onPressed: () => Navigator.of(ctx).pop()),
                    ],
                  ),
                  Divider(height: 20, color: _cardBorder),
                  Expanded(
                    child: loading
                        ? const Center(child: CircularProgressIndicator())
                        : studentList.isEmpty
                            ? Center(
                                child: Text(
                                    'No results computed yet. Please enter marks first.',
                                    style: TextStyle(color: _textSecondary)))
                            : ListView.builder(
                                itemCount: studentList.length,
                                itemBuilder: (context, idx) {
                                  final st = studentList[idx];
                                  final rank = st['rank'] ?? (idx + 1);
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: _innerCardBg,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: _cardBorder),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            color: rank <= 3
                                                ? const Color(0xFFFEF3C7)
                                                : _cardBorder,
                                            shape: BoxShape.circle,
                                          ),
                                          alignment: Alignment.center,
                                          child: Text('$rank',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w700,
                                                  color: rank <= 3
                                                      ? const Color(0xFFB45309)
                                                      : _textSecondary)),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                  st['student_name'] ??
                                                      'Student',
                                                  style: TextStyle(
                                                      fontSize: 13.5,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: _textPrimary)),
                                              Text(
                                                  'Roll No: ${st['roll_number'] ?? '-'} • ${st['class_name'] ?? 'Class 10'}',
                                                  style: TextStyle(
                                                      fontSize: 11,
                                                      color: _textSecondary)),
                                            ],
                                          ),
                                        ),
                                        Text(
                                            '${st['total_marks_obtained'] ?? '-'} / ${st['max_marks'] ?? 100}',
                                            style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: _textPrimary)),
                                        const SizedBox(width: 16),
                                        _buildGradePill(
                                            st['grade']?.toString() ?? 'A1'),
                                      ],
                                    ),
                                  );
                                },
                              ),
                  ),
                  Divider(height: 20, color: _cardBorder),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _textSecondary,
                          side: BorderSide(color: _cardBorder),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Close'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            await _apiService.publishExamResults(examId);
                            _loadDashboardOverview();
                            _loadExamsTable();
                            if (mounted) {
                              Navigator.of(ctx).pop();
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(const SnackBar(
                                content: Text(
                                    'Results published to students and parents portal!'),
                                backgroundColor: Color(0xFF16A34A),
                              ));
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context)
                                  .showSnackBar(SnackBar(
                                content: Text('Failed to publish results: $e'),
                                backgroundColor: const Color(0xFFDC2626),
                              ));
                            }
                          }
                        },
                        icon: const Icon(Icons.publish_rounded, size: 16),
                        label: const Text('Publish Results to Portal'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF16A34A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _downloadExamPdf(String examId) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Generating printable exam paper PDF...')));
      final pdfBytes = await _apiService.downloadExamPaperPdf(examId);
      final filename =
          'exam_paper_${examId.length > 8 ? examId.substring(0, 8) : examId}.pdf';
      await getDownloadHelper().downloadBytes(pdfBytes, filename);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Question paper PDF downloaded successfully!'),
            backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('PDF download: $e'),
            backgroundColor: const Color(0xFFDC2626)));
      }
    }
  }

  void _confirmDeleteExam(Map<String, dynamic> exam) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _cardBorder),
        ),
        title: Text('Delete Examination?',
            style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w700)),
        content: Text(
            'Are you sure you want to delete "${exam['title']}"? This action will cascade delete all scheduled slots and question papers.',
            style: TextStyle(color: _textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _apiService.deleteExam(exam['id']);
              _loadDashboardOverview();
              _loadExamsTable();
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Examination removed successfully')));
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8))),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
