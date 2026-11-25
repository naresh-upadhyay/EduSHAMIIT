import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:edu_shamiit_core/services/api_service.dart';
import 'package:edu_shamiit_admin/widgets/hr_management_tab_header.dart';
import 'package:edu_shamiit_admin/services/hr_lookup_helper.dart';
import 'package:intl/intl.dart';

import '../../../core/file_download_helper.dart';
import 'widgets/start_onboarding_dialog.dart';
import 'widgets/onboarding_detail_drawer.dart';
import 'widgets/onboarding_pipeline_dialog.dart';
import 'widgets/department_onboarding_report_dialog.dart';
import 'widgets/onboarding_tasks_dialog.dart';
import 'widgets/onboarding_documents_dialog.dart';
import 'widgets/onboarding_document_viewer_dialog.dart';
import 'widgets/onboarding_activity_log_dialog.dart';
import 'widgets/onboarding_stage_transition_dialog.dart';
import 'widgets/onboarding_guide_dialog.dart';

class HROnboardingScreen extends StatefulWidget {
  const HROnboardingScreen({super.key});

  @override
  State<HROnboardingScreen> createState() => _HROnboardingScreenState();
}

class _HROnboardingScreenState extends State<HROnboardingScreen> {
  final ApiService _api = ApiService();

  bool _isLoadingDashboard = true;
  bool _isLoadingRecords = true;
  String? _errorMessage;

  // Dashboard Data
  Map<String, dynamic> _metrics = {
    'total_onboardings': 48,
    'in_progress': 12,
    'pending_documents': 9,
    'completed': 27,
    'avg_time_days': 6,
    'satisfaction_rate': 92.0,
  };
  List<dynamic> _pipeline = [];
  List<dynamic> _departmentsBreakdown = [];
  List<dynamic> _recentTasks = [];
  List<dynamic> _recentDocuments = [];
  List<dynamic> _recentActivities = [];

  // Table Data & Filters
  List<dynamic> _records = [];
  Map<String, dynamic> _pagination = {
    'page': 1,
    'page_size': 10,
    'total_records': 0,
    'total_pages': 1,
  };
  int _pageSize = 10;
  String _sortBy = 'joining_date';
  bool _sortAsc = true;
  int? _sortColumnIndex = 5;

  String _searchQuery = '';
  String _selectedDepartment = 'All';
  String _selectedStage = 'All';
  String _selectedStatus = 'All';

  final TextEditingController _searchController = TextEditingController();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String? _drawerOnboardingId;

  List<String> _departmentsList = ['All', ...HRLookupHelper.instance.getCachedLabels('DEPARTMENT')];

  @override
  void initState() {
    super.initState();
    HRLookupHelper.instance.addListener(_onLookupsChanged);
    _loadAllData();
  }

  void _onLookupsChanged() {
    if (mounted) {
      _loadDepartmentLookups(true);
    }
  }

  @override
  void dispose() {
    HRLookupHelper.instance.removeListener(_onLookupsChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    await Future.wait([
      _fetchDashboard(),
      _fetchRecords(page: 1),
      _loadDepartmentLookups(true),
    ]);
  }

  Future<void> _loadDepartmentLookups([bool forceRefresh = true]) async {
    final depts = await HRLookupHelper.instance.getLookupLabels('DEPARTMENT', forceRefresh: forceRefresh);
    if (mounted) {
      setState(() {
        _departmentsList = ['All', ...depts];
        if (!_departmentsList.contains(_selectedDepartment)) {
          _selectedDepartment = 'All';
        }
      });
    }
  }

  Future<void> _fetchDashboard() async {
    if (!mounted) return;
    setState(() => _isLoadingDashboard = true);
    try {
      final res = await _api.get('/onboarding/dashboard', useCache: false);
      if (res['success'] == true) {
        final data = res['data'] as Map<String, dynamic>? ?? {};
        if (!mounted) return;
        setState(() {
          _metrics = data['metrics'] as Map<String, dynamic>? ?? _metrics;
          _pipeline = data['pipeline'] as List<dynamic>? ?? [];
          _departmentsBreakdown = data['department_breakdown'] as List<dynamic>? ?? [];
          _recentTasks = data['recent_tasks'] as List<dynamic>? ?? [];
          _recentDocuments = data['recent_documents'] as List<dynamic>? ?? [];
          _recentActivities = data['recent_activities'] as List<dynamic>? ?? [];
          _isLoadingDashboard = false;
        });
      } else {
        if (!mounted) return;
        setState(() => _isLoadingDashboard = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingDashboard = false);
    }
  }

  Future<void> _fetchRecords({int page = 1}) async {
    if (!mounted) return;
    setState(() {
      _isLoadingRecords = true;
      _errorMessage = null;
    });

    final query = <String, dynamic>{
      'page': page,
      'page_size': _pageSize,
      'sort_by': _sortBy,
      'sort_order': _sortAsc ? 'asc' : 'desc',
    };

    if (_searchQuery.trim().isNotEmpty) {
      query['search'] = _searchQuery.trim();
    }
    if (_selectedDepartment != 'All') {
      query['department'] = _selectedDepartment;
    }
    if (_selectedStage != 'All') {
      query['stage'] = _selectedStage;
    }
    if (_selectedStatus != 'All') {
      query['status'] = _selectedStatus;
    }

    try {
      final res = await _api.get('/onboarding/records', query: query, useCache: false);
      if (!mounted) return;
      if (res['success'] == true) {
        setState(() {
          _records = res['data'] as List<dynamic>? ?? [];
          _pagination = res['pagination'] as Map<String, dynamic>? ?? _pagination;
          _isLoadingRecords = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _errorMessage = res['detail'] ?? 'Failed to load records.';
          _isLoadingRecords = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceAll('ApiException: ', '');
        _isLoadingRecords = false;
      });
    }
  }

  Future<void> _exportOnboardingCsv() async {
    try {
      final queryParams = <String>[];
      if (_selectedDepartment != 'All') queryParams.add('department=$_selectedDepartment');
      if (_selectedStage != 'All') queryParams.add('stage=$_selectedStage');
      if (_selectedStatus != 'All') queryParams.add('status=$_selectedStatus');
      final queryStr = queryParams.isNotEmpty ? '?${queryParams.join('&')}' : '';

      final res = await _api.getString('/onboarding/export$queryStr');
      if (mounted) {
        downloadFile(res, 'onboarding_records_${DateTime.now().millisecondsSinceEpoch}.csv');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Onboarding records downloaded successfully (${res.length} bytes).'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export onboarding records: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _openStartOnboardingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StartOnboardingDialog(
        onOnboardingCreated: () {
          _loadAllData();
        },
      ),
    );
  }

  void _openDetailDrawer(String onboardingId) {
    setState(() => _drawerOnboardingId = onboardingId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _scaffoldKey.currentState?.openEndDrawer();
      }
    });
  }

  Future<void> _toggleRecentTask(String taskId, String currentStatus) async {
    final newStatus = currentStatus == 'Completed' ? 'In Progress' : 'Completed';
    try {
      final res = await _api.patch('/onboarding/tasks/$taskId', {'status': newStatus});
      if (res['success'] == true) {
        _fetchDashboard();
        _fetchRecords(page: _pagination['page'] ?? 1);
      }
    } catch (_) {}
  }

  void _openOnboardingPipelineDialog({String stage = 'All', String? department}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => OnboardingPipelineDialog(
        initialStage: stage,
        initialDepartment: department,
        onDataChanged: _loadAllData,
      ),
    );
  }

  void _openStageTransitionDialog(Map<String, dynamic> r) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => OnboardingStageTransitionDialog(
        onboardingId: r['id'].toString(),
        candidateName: r['candidate_name']?.toString() ?? 'New Hire',
        onboardingCode: r['onboarding_code']?.toString() ?? 'EMP',
        designation: r['designation']?.toString() ?? 'Staff',
        department: r['department']?.toString() ?? 'Academics',
        currentStage: r['stage']?.toString() ?? 'Offer Accepted',
        onStageChanged: _loadAllData,
      ),
    );
  }

  Future<void> _sendReminderWithFeedback(String onboardingId, String candidateName, String? email) async {
    final noteCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.notifications_active_outlined, color: Color(0xFFF59E0B), size: 20),
            ),
            const SizedBox(width: 10),
            const Text('Send Onboarding Reminder', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Send a detailed onboarding checklist reminder to $candidateName (${email ?? 'no email'}).', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 6),
            const Text(
              'The candidate will receive an email listing their pending documents, tasks, expected joining date, and reporting venue.',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: noteCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Custom Note to Candidate (Optional)',
                hintText: 'e.g. Please bring original degree certificates on Monday morning.',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.send_rounded, size: 15, color: Colors.white),
            label: const Text('Send Reminder Email', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await _api.post('/onboarding/records/$onboardingId/reminder', {
        'custom_message': noteCtrl.text.trim(),
        'send_email': true,
      });
      if (!mounted) return;
      final emailSent = res['data']?['email_sent'] == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(res['message'] ?? 'Reminder sent successfully!'),
          backgroundColor: emailSent ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _fetchRecords(page: _pagination['page'] ?? 1);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('ApiException: ', '')),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }


  void _openDepartmentReportDialog() {
    final total = _metrics['total_onboardings'] ?? 0;
    final inProgress = _metrics['in_progress'] ?? 0;
    final completed = _metrics['completed'] ?? 0;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => DepartmentOnboardingReportDialog(
        departmentBreakdown: _departmentsBreakdown,
        totalOnboardings: total,
        inProgress: inProgress,
        completed: completed,
        onDataChanged: _loadAllData,
      ),
    );
  }

  void _openTasksDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => OnboardingTasksDialog(
        onDataChanged: _loadAllData,
      ),
    );
  }

  void _openDocumentsDialog({String status = 'All'}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => OnboardingDocumentsDialog(
        initialStatus: status,
        onDataChanged: _loadAllData,
      ),
    );
  }

  void _openActivityLogDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const OnboardingActivityLogDialog(),
    );
  }

  Widget _buildActiveFilterChip(String label, VoidCallback onDeleted) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4F46E5),
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onDeleted,
            borderRadius: BorderRadius.circular(10),
            child: const Icon(
              Icons.close_rounded,
              size: 13,
              color: Color(0xFF4F46E5),
            ),
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
      key: _scaffoldKey,
      backgroundColor: isDark ? const Color(0xFF090D1A) : const Color(0xFFF8FAFC),
      endDrawer: Drawer(
        width: math.min(720.0, MediaQuery.of(context).size.width * 0.92),
        child: _drawerOnboardingId != null
            ? OnboardingDetailDrawer(
                key: ValueKey(_drawerOnboardingId),
                onboardingId: _drawerOnboardingId!,
                onActionCompleted: _loadAllData,
                onClose: () {
                  if (_scaffoldKey.currentState?.isEndDrawerOpen ?? false) {
                    _scaffoldKey.currentState?.closeEndDrawer();
                  } else {
                    Navigator.of(context).maybePop();
                  }
                },
              )
            : const SizedBox.shrink(),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Unified HR Management Header (Active Tab: Onboarding)
          HRManagementHeader(
            activeTab: HRTab.onboarding,
            title: 'Onboarding',
            subtitle: 'Manage new hires onboarding process and track their progress.',
            icon: Icons.person_add_alt_1_rounded,
            onRefresh: _loadAllData,
            isRefreshing: _isLoadingDashboard,
            actions: [
              OutlinedButton.icon(
                onPressed: () => _showSettingsDialog(isDark),
                icon: Icon(Icons.settings_outlined, size: 16, color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5)),
                label: Text(
                  'Onboarding Settings',
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
                onPressed: _openStartOnboardingDialog,
                icon: const Icon(Icons.add, size: 16, color: Colors.white),
                label: const Text(
                  'Add New Hire',
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
                  if (val == 'export') {
                    _exportOnboardingCsv();
                  } else if (val == 'refresh') {
                    _loadAllData();
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'export', child: Text('Export CSV Report')),
                  const PopupMenuItem(value: 'refresh', child: Text('Refresh Dashboard')),
                ],
              ),
            ],
          ),
          if (_isLoadingDashboard && _pipeline.isEmpty)
            const LinearProgressIndicator(minHeight: 3),

          // Main Scrollable Dashboard Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [

                  // 2. KPI Metrics Cards (6 interactive cards)
                  _buildKpiCardsRow(isDark),
                  const SizedBox(height: 24),

                  // 3. Pipeline & Department Row (65% / 35%)
                  LayoutBuilder(
                    builder: (ctx, constraints) {
                      if (constraints.maxWidth < 1100) {
                        return Column(
                          children: [
                            _buildOnboardingProgressCard(isDark),
                            const SizedBox(height: 20),
                            _buildDepartmentBreakdownCard(isDark),
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 65, child: _buildOnboardingProgressCard(isDark)),
                          const SizedBox(width: 20),
                          Expanded(flex: 35, child: _buildDepartmentBreakdownCard(isDark)),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // 4. Middle Row: New Joiners Table & Onboarding Tasks
                  LayoutBuilder(
                    builder: (ctx, constraints) {
                      if (constraints.maxWidth < 1240) {
                        return Column(
                          children: [
                            _buildNewJoinersTableCard(isDark),
                            const SizedBox(height: 20),
                            _buildTasksChecklistCard(isDark),
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 68, child: _buildNewJoinersTableCard(isDark)),
                          const SizedBox(width: 20),
                          Expanded(flex: 32, child: _buildTasksChecklistCard(isDark)),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // 5. Bottom Row: Activities, Documents, and Guide Banner (33% each)
                  LayoutBuilder(
                    builder: (ctx, constraints) {
                      if (constraints.maxWidth < 1080) {
                        return Column(
                          children: [
                            _buildRecentActivitiesCard(isDark),
                            const SizedBox(height: 20),
                            _buildOnboardingDocumentsCard(isDark),
                            const SizedBox(height: 20),
                            _buildGuideBannerCard(isDark),
                          ],
                        );
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildRecentActivitiesCard(isDark)),
                          const SizedBox(width: 20),
                          Expanded(child: _buildOnboardingDocumentsCard(isDark)),
                          const SizedBox(width: 20),
                          Expanded(child: _buildGuideBannerCard(isDark)),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }



  void _openOnboardingGuideDialog({int initialTab = 0}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => OnboardingGuideDialog(
        initialTabIndex: initialTab,
        onAddNewHire: _openStartOnboardingDialog,
        onOpenPipeline: () => _openOnboardingPipelineDialog(),
      ),
    );
  }

  void _showSettingsDialog(bool isDark) {
    _openOnboardingGuideDialog(initialTab: 1);
  }

  // ==========================================================================
  // SECTION 2: 6 KPI METRICS CARDS ROW
  // ==========================================================================
  Widget _buildKpiCardsRow(bool isDark) {
    final total = _metrics['total_onboardings'] ?? 0;
    final inProgress = _metrics['in_progress'] ?? 0;
    final pendingDocs = _metrics['pending_documents'] ?? 0;
    final candidatesWithPending = _metrics['candidates_with_pending_docs'] ?? 0;
    final completed = _metrics['completed'] ?? 0;
    final avgDays = _metrics['avg_time_days'] ?? 0;
    final satisfaction = _metrics['satisfaction_rate'] ?? 0.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildKpiCard(
            title: 'Total Onboardings',
            value: '$total',
            trend: _metrics['total_trend']?.toString() ?? 'Active Pipeline',
            isPositive: true,
            icon: Icons.people_outline_rounded,
            iconBg: const Color(0xFF6366F1),
            isDark: isDark,
            onTap: () {
              setState(() {
                _selectedStatus = 'All';
                _selectedStage = 'All';
              });
              _fetchRecords(page: 1);
            },
          ),
          const SizedBox(width: 14),
          _buildKpiCard(
            title: 'In Progress',
            value: '$inProgress',
            trend: '↑ 4% vs last month',
            isPositive: true,
            icon: Icons.assignment_outlined,
            iconBg: const Color(0xFF0EA5E9),
            isDark: isDark,
            onTap: () {
              setState(() => _selectedStatus = 'In Progress');
              _fetchRecords(page: 1);
            },
          ),
          const SizedBox(width: 14),
          _buildKpiCard(
            title: 'Pending Documents',
            value: '$pendingDocs',
            trend: 'Across $candidatesWithPending new hires',
            isPositive: false,
            icon: Icons.access_time_rounded,
            iconBg: const Color(0xFFF43F5E),
            isDark: isDark,
            onTap: () => _openDocumentsDialog(status: 'Pending'),
          ),
          const SizedBox(width: 14),
          _buildKpiCard(
            title: 'Completed',
            value: '$completed',
            trend: '↑ 18% vs last month',
            isPositive: true,
            icon: Icons.event_available_outlined,
            iconBg: const Color(0xFF10B981),
            isDark: isDark,
            onTap: () {
              setState(() => _selectedStatus = 'Completed');
              _fetchRecords(page: 1);
            },
          ),
          const SizedBox(width: 14),
          _buildKpiCard(
            title: 'Avg. Time to Complete',
            value: '$avgDays Days',
            trend: '↓ 25% vs last month',
            isPositive: true,
            icon: Icons.hourglass_empty_rounded,
            iconBg: const Color(0xFF8B5CF6),
            isDark: isDark,
            onTap: () {},
          ),
          const SizedBox(width: 14),
          _buildKpiCard(
            title: 'Onboarding Satisfaction',
            value: '${satisfaction.toInt()}%',
            trend: '↑ 6% vs last month',
            isPositive: true,
            icon: Icons.star_outline_rounded,
            iconBg: const Color(0xFFF59E0B),
            isDark: isDark,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String trend,
    required bool isPositive,
    required IconData icon,
    required Color iconBg,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 195,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF13182C) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconBg.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconBg, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              trend,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // SECTION 3: ONBOARDING PROGRESS PIPELINE CARD
  // ==========================================================================
  Widget _buildOnboardingProgressCard(bool isDark) {
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
              Text(
                'Onboarding Progress',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_selectedStage != 'All')
                    TextButton(
                      onPressed: () {
                        setState(() => _selectedStage = 'All');
                        _fetchRecords(page: 1);
                      },
                      child: const Text('Clear Stage Filter', style: TextStyle(fontSize: 12, color: Color(0xFF4F46E5))),
                    ),
                  TextButton(
                    onPressed: () => _openOnboardingPipelineDialog(stage: _selectedStage),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                    child: const Text(
                      'View Details →',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 6 Stage progression items connected by arrows
          _pipeline.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(_pipeline.length, (idx) {
                      final item = _pipeline[idx];
                      final isSelected = _selectedStage == item['stage'];
                      return Row(
                        children: [
                          _buildPipelineStageItem(
                            stage: item['stage'] ?? '',
                            count: item['count'] ?? 0,
                            pct: (item['percentage'] as num?)?.toDouble() ?? 0.0,
                            icon: _getPipelineIcon(item['stage']),
                            iconColor: _getPipelineColor(idx),
                            isSelected: isSelected,
                            isDark: isDark,
                            onTap: () {
                              setState(() {
                                _selectedStage = isSelected ? 'All' : item['stage'];
                              });
                              _fetchRecords(page: 1);
                            },
                          ),
                          if (idx < _pipeline.length - 1)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              child: Icon(
                                Icons.arrow_forward_rounded,
                                size: 16,
                                color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                              ),
                            ),
                        ],
                      );
                    }),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildPipelineStageItem({
    required String stage,
    required int count,
    required double pct,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF4F46E5).withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isSelected ? Border.all(color: const Color(0xFF4F46E5), width: 1.5) : null,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 10),
            Text(
              stage,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF4F46E5)
                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${pct.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getPipelineIcon(String? stage) {
    switch (stage) {
      case 'Offer Accepted':
        return Icons.handshake_outlined;
      case 'Document Collection':
        return Icons.description_outlined;
      case 'Orientation':
        return Icons.how_to_reg_outlined;
      case 'IT Setup':
        return Icons.computer_outlined;
      case 'Training':
        return Icons.school_outlined;
      case 'Completed':
        return Icons.verified_outlined;
      default:
        return Icons.circle_outlined;
    }
  }

  Color _getPipelineColor(int index) {
    const colors = [
      Color(0xFF6366F1), // Purple
      Color(0xFF0EA5E9), // Blue
      Color(0xFF10B981), // Green
      Color(0xFFF59E0B), // Amber
      Color(0xFFEC4899), // Pink
      Color(0xFF8B5CF6), // Violet
    ];
    return colors[index % colors.length];
  }

  // ==========================================================================
  // SECTION 4: ONBOARDING BY DEPARTMENT CARD
  // ==========================================================================
  Widget _buildDepartmentBreakdownCard(bool isDark) {
    final total = _metrics['total_onboardings'] ?? 0;

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
              Text(
                'Onboarding by Department',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              TextButton(
                onPressed: _openDepartmentReportDialog,
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                child: const Text(
                  'View Report →',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4F46E5)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              // Custom Donut Chart
              SizedBox(
                width: 110,
                height: 110,
                child: CustomPaint(
                  painter: _DepartmentDonutPainter(
                    items: _departmentsBreakdown,
                    total: total,
                    isDark: isDark,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$total',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Legend
              Expanded(
                child: Column(
                  children: _departmentsBreakdown.map((d) {
                    final color = _getDeptColor(d['department'] ?? '');
                    final isSelected = _selectedDepartment == d['department'];
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedDepartment = isSelected ? 'All' : d['department'];
                        });
                        _fetchRecords(page: 1);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                d['department'] ?? '',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? const Color(0xFF4F46E5) : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                ),
                              ),
                            ),
                            Text(
                              '${d['count']}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '(${d['percentage']}%)',
                              style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getDeptColor(String dept) {
    switch (dept) {
      case 'Academics':
        return const Color(0xFF4F46E5);
      case 'Administration':
        return const Color(0xFF0EA5E9);
      case 'IT / Technical':
        return const Color(0xFF06B6D4);
      case 'Finance':
        return const Color(0xFF10B981);
      case 'Transport':
        return const Color(0xFFEC4899);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  Color _getStageColor(String? stage) {
    switch (stage) {
      case 'Offer Accepted':
        return const Color(0xFF6366F1);
      case 'Document Collection':
        return const Color(0xFF0EA5E9);
      case 'Orientation':
        return const Color(0xFF10B981);
      case 'IT Setup':
        return const Color(0xFFF59E0B);
      case 'Training':
        return const Color(0xFFEC4899);
      case 'Completed':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF64748B);
    }
  }

  // ==========================================================================
  // SECTION 5: NEW JOINERS (RECENT) TABLE CARD
  // ==========================================================================
  Widget _buildNewJoinersTableCard(bool isDark) {
    final hasActiveFilters = _selectedDepartment != 'All' || _selectedStage != 'All' || _selectedStatus != 'All' || _searchQuery.isNotEmpty;

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
            spacing: 12,
            runSpacing: 10,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'New Joiners',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${_pagination['total_records'] ?? _records.length} ${_selectedStage != 'All' ? 'in $_selectedStage' : 'Total'}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4F46E5),
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasActiveFilters)
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedDepartment = 'All';
                          _selectedStatus = 'All';
                          _selectedStage = 'All';
                          _searchQuery = '';
                          _searchController.clear();
                        });
                        _fetchRecords(page: 1);
                      },
                      icon: const Icon(Icons.clear_all_rounded, size: 14, color: Color(0xFFEF4444)),
                      label: const Text('Reset Filters', style: TextStyle(fontSize: 12, color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                    ),
                  TextButton.icon(
                    onPressed: () => _openOnboardingPipelineDialog(stage: _selectedStage, department: _selectedDepartment != 'All' ? _selectedDepartment : null),
                    icon: const Icon(Icons.open_in_new_rounded, size: 14, color: Color(0xFF4F46E5)),
                    label: const Text('Pipeline Workspace →', style: TextStyle(fontSize: 12, color: Color(0xFF4F46E5), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Filters toolbar: Search + Department + Stage Dropdowns (Responsive)
          LayoutBuilder(
            builder: (ctx, filterConstraints) {
              final isNarrow = filterConstraints.maxWidth < 680;
              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: 'Search by employee name, ID, email, designation...',
                          hintStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search_rounded, size: 18),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () {
                                    _searchController.clear();
                                    _searchQuery = '';
                                    _fetchRecords(page: 1);
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0B0E1B) : const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (val) {
                          _searchQuery = val;
                          _fetchRecords(page: 1);
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0B0E1B) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: AppSearchableDropdown<String>.fromMenuItems(
                                isExpanded: true,
                                value: _departmentsList.contains(_selectedDepartment) ? _selectedDepartment : 'All',
                                items: _departmentsList
                                    .map((d) => DropdownMenuItem(
                                          value: d,
                                          child: Text(
                                            d == 'All' ? 'All Departments' : d,
                                            style: const TextStyle(fontSize: 12),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ))
                                    .toList(),
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedDepartment = val);
                                    _fetchRecords(page: 1);
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Container(
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF0B0E1B) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: AppSearchableDropdown<String>.fromMenuItems(
                                isExpanded: true,
                                value: ['All', 'Offer Accepted', 'Document Collection', 'Orientation', 'IT Setup', 'Training', 'Completed'].contains(_selectedStage)
                                    ? _selectedStage
                                    : 'All',
                                items: const [
                                  DropdownMenuItem(value: 'All', child: Text('All Stages', style: TextStyle(fontSize: 12))),
                                  DropdownMenuItem(value: 'Offer Accepted', child: Text('Offer Accepted', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                                  DropdownMenuItem(value: 'Document Collection', child: Text('Document Collection', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                                  DropdownMenuItem(value: 'Orientation', child: Text('Orientation', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                                  DropdownMenuItem(value: 'IT Setup', child: Text('IT Setup', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                                  DropdownMenuItem(value: 'Training', child: Text('Training', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                                  DropdownMenuItem(value: 'Completed', child: Text('Completed', style: TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis)),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _selectedStage = val);
                                    _fetchRecords(page: 1);
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 38,
                      child: TextField(
                        controller: _searchController,
                        style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                        decoration: InputDecoration(
                          hintText: 'Search by employee name, ID, email, designation...',
                          hintStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                          prefixIcon: const Icon(Icons.search_rounded, size: 18),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 16),
                                  onPressed: () {
                                    _searchController.clear();
                                    _searchQuery = '';
                                    _fetchRecords(page: 1);
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: isDark ? const Color(0xFF0B0E1B) : const Color(0xFFF8FAFC),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (val) {
                          _searchQuery = val;
                          _fetchRecords(page: 1);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0B0E1B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: AppSearchableDropdown<String>.fromMenuItems(
                        value: _departmentsList.contains(_selectedDepartment) ? _selectedDepartment : 'All',
                        items: _departmentsList.map((d) => DropdownMenuItem(value: d, child: Text(d == 'All' ? 'All Departments' : d, style: const TextStyle(fontSize: 12)))).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedDepartment = val);
                            _fetchRecords(page: 1);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    height: 38,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0B0E1B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: AppSearchableDropdown<String>.fromMenuItems(
                        value: ['All', 'Offer Accepted', 'Document Collection', 'Orientation', 'IT Setup', 'Training', 'Completed'].contains(_selectedStage)
                            ? _selectedStage
                            : 'All',
                        items: const [
                          DropdownMenuItem(value: 'All', child: Text('All Stages', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'Offer Accepted', child: Text('Offer Accepted', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'Document Collection', child: Text('Document Collection', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'Orientation', child: Text('Orientation', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'IT Setup', child: Text('IT Setup', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'Training', child: Text('Training', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'Completed', child: Text('Completed', style: TextStyle(fontSize: 12))),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedStage = val);
                            _fetchRecords(page: 1);
                          }
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // Active Filter Chips bar
          if (hasActiveFilters) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Active Filters:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
                if (_searchQuery.isNotEmpty)
                  _buildActiveFilterChip('Search: "$_searchQuery"', () {
                    setState(() {
                      _searchQuery = '';
                      _searchController.clear();
                    });
                    _fetchRecords(page: 1);
                  }),
                if (_selectedDepartment != 'All')
                  _buildActiveFilterChip('Dept: $_selectedDepartment', () {
                    setState(() => _selectedDepartment = 'All');
                    _fetchRecords(page: 1);
                  }),
                if (_selectedStage != 'All')
                  _buildActiveFilterChip('Stage: $_selectedStage', () {
                    setState(() => _selectedStage = 'All');
                    _fetchRecords(page: 1);
                  }),
                if (_selectedStatus != 'All')
                  _buildActiveFilterChip('Status: $_selectedStatus', () {
                    setState(() => _selectedStatus = 'All');
                    _fetchRecords(page: 1);
                  }),
                InkWell(
                  onTap: () {
                    setState(() {
                      _selectedDepartment = 'All';
                      _selectedStage = 'All';
                      _selectedStatus = 'All';
                      _searchQuery = '';
                      _searchController.clear();
                    });
                    _fetchRecords(page: 1);
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      'Clear All',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFEF4444), decoration: TextDecoration.underline),
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),

          // Status Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'In Progress', 'Completed', 'Pending'].map((st) {
                final isSelected = _selectedStatus == st;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(st, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
                    selected: isSelected,
                    selectedColor: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                    labelStyle: TextStyle(color: isSelected ? const Color(0xFF4F46E5) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                    onSelected: (_) {
                      setState(() => _selectedStatus = st);
                      _fetchRecords(page: 1);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 14),

          // Table Content
          _isLoadingRecords
              ? const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                )
              : _records.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(40),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          const Icon(Icons.inbox_outlined, size: 40, color: Color(0xFF94A3B8)),
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage ?? 'No matching onboarding records found.',
                            style: TextStyle(
                              fontSize: 13,
                              color: _errorMessage != null ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(minWidth: 1040),
                        child: DataTable(
                          columnSpacing: 18,
                          horizontalMargin: 12,
                          headingRowHeight: 44,
                          dataRowMinHeight: 52,
                          dataRowMaxHeight: 56,
                          sortColumnIndex: _sortColumnIndex,
                          sortAscending: _sortAsc,
                          columns: [
                            DataColumn(
                              label: const SizedBox(width: 85, child: Text('Employee ID', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              onSort: (idx, asc) {
                                setState(() {
                                  _sortColumnIndex = idx;
                                  _sortBy = 'onboarding_code';
                                  _sortAsc = asc;
                                });
                                _fetchRecords(page: 1);
                              },
                            ),
                            DataColumn(
                              label: const SizedBox(width: 150, child: Text('Name', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              onSort: (idx, asc) {
                                setState(() {
                                  _sortColumnIndex = idx;
                                  _sortBy = 'candidate_name';
                                  _sortAsc = asc;
                                });
                                _fetchRecords(page: 1);
                              },
                            ),
                            DataColumn(
                              label: const SizedBox(width: 110, child: Text('Department', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              onSort: (idx, asc) {
                                setState(() {
                                  _sortColumnIndex = idx;
                                  _sortBy = 'department';
                                  _sortAsc = asc;
                                });
                                _fetchRecords(page: 1);
                              },
                            ),
                            DataColumn(
                              label: const SizedBox(width: 150, child: Text('Designation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              onSort: (idx, asc) {
                                setState(() {
                                  _sortColumnIndex = idx;
                                  _sortBy = 'designation';
                                  _sortAsc = asc;
                                });
                                _fetchRecords(page: 1);
                              },
                            ),
                            DataColumn(
                              label: const SizedBox(width: 150, child: Text('Stage', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              onSort: (idx, asc) {
                                setState(() {
                                  _sortColumnIndex = idx;
                                  _sortBy = 'stage';
                                  _sortAsc = asc;
                                });
                                _fetchRecords(page: 1);
                              },
                            ),
                            DataColumn(
                              label: const SizedBox(width: 100, child: Text('Joining Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              onSort: (idx, asc) {
                                setState(() {
                                  _sortColumnIndex = idx;
                                  _sortBy = 'joining_date';
                                  _sortAsc = asc;
                                });
                                _fetchRecords(page: 1);
                              },
                            ),
                            DataColumn(
                              label: const SizedBox(width: 100, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              onSort: (idx, asc) {
                                setState(() {
                                  _sortColumnIndex = idx;
                                  _sortBy = 'status';
                                  _sortAsc = asc;
                                });
                                _fetchRecords(page: 1);
                              },
                            ),
                            const DataColumn(label: SizedBox(width: 80, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)))),
                          ],
                          rows: _records.map((r) {
                            final status = r['status'] ?? 'Pending';
                            final isCompleted = status == 'Completed';
                            final isInProgress = status == 'In Progress';

                            Color badgeBg;
                            Color badgeFg;
                            if (isCompleted) {
                              badgeBg = const Color(0xFF10B981).withValues(alpha: 0.1);
                              badgeFg = const Color(0xFF10B981);
                            } else if (isInProgress) {
                              badgeBg = const Color(0xFF3B82F6).withValues(alpha: 0.1);
                              badgeFg = const Color(0xFF3B82F6);
                            } else {
                              badgeBg = const Color(0xFFF59E0B).withValues(alpha: 0.1);
                              badgeFg = const Color(0xFFF59E0B);
                            }

                            final stageName = r['stage'] ?? 'Offer Accepted';
                            final stageColor = _getStageColor(stageName);

                            return DataRow(
                              cells: [
                                // Employee ID
                                DataCell(
                                  SizedBox(
                                    width: 85,
                                    child: Text(
                                      r['onboarding_code'] ?? 'EMP',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF4F46E5)),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ),
                                // Name
                                DataCell(
                                  SizedBox(
                                    width: 150,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                                          child: Text(
                                            r['candidate_name'] != null && r['candidate_name'].toString().isNotEmpty
                                                ? r['candidate_name'][0].toUpperCase()
                                                : 'E',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            r['candidate_name'] ?? 'New Hire',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // Department
                                DataCell(
                                  SizedBox(
                                    width: 110,
                                    child: Text(
                                      r['department'] ?? 'Academics',
                                      style: const TextStyle(fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ),
                                // Designation
                                DataCell(
                                  SizedBox(
                                    width: 150,
                                    child: Text(
                                      r['designation'] ?? 'Teacher',
                                      style: const TextStyle(fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ),
                                // Stage
                                DataCell(
                                  SizedBox(
                                    width: 150,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: InkWell(
                                        onTap: () => _openStageTransitionDialog(r),
                                        borderRadius: BorderRadius.circular(6),
                                        child: Tooltip(
                                          message: 'Click to advance or change stage',
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: stageColor.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(color: stageColor.withValues(alpha: 0.4)),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    stageName,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: stageColor,
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                Icon(Icons.edit_outlined, size: 12, color: stageColor),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Joining Date
                                DataCell(
                                  SizedBox(
                                    width: 100,
                                    child: Text(
                                      r['joining_date'] != null
                                          ? DateFormat('dd MMM yyyy').format(DateTime.parse(r['joining_date'].toString()))
                                          : 'N/A',
                                      style: const TextStyle(fontSize: 12),
                                      maxLines: 1,
                                    ),
                                  ),
                                ),
                                // Status
                                DataCell(
                                  SizedBox(
                                    width: 100,
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(6)),
                                        child: Text(
                                          status,
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badgeFg),
                                          maxLines: 1,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Actions
                                DataCell(
                                  SizedBox(
                                    width: 80,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: const Icon(Icons.visibility_outlined, size: 18),
                                          tooltip: 'View 360 Detail',
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                          onPressed: () => _openDetailDrawer(r['id'].toString()),
                                        ),
                                        PopupMenuButton<String>(
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                          icon: const Icon(Icons.more_vert_rounded, size: 18),
                                          onSelected: (action) async {
                                            if (action == 'stage') {
                                              _openStageTransitionDialog(r);
                                            } else if (action == 'complete') {
                                              await _api.post('/onboarding/records/${r['id']}/complete', {'override_blockers': true, 'override_reason': 'Quick completed'});
                                              _loadAllData();
                                            } else if (action == 'reminder') {
                                              _sendReminderWithFeedback(
                                                r['id'].toString(),
                                                r['candidate_name']?.toString() ?? 'candidate',
                                                r['candidate_email']?.toString(),
                                              );
                                            }
                                          },
                                          itemBuilder: (ctx) => [
                                            const PopupMenuItem(
                                              value: 'stage',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.published_with_changes_rounded, size: 16, color: Color(0xFF4F46E5)),
                                                  SizedBox(width: 8),
                                                  Text('Advance / Change Stage'),
                                                ],
                                              ),
                                            ),
                                            const PopupMenuItem(
                                              value: 'reminder',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.notifications_active_outlined, size: 16, color: Color(0xFFF59E0B)),
                                                  SizedBox(width: 8),
                                                  Text('Send Reminder'),
                                                ],
                                              ),
                                            ),
                                            const PopupMenuItem(
                                              value: 'complete',
                                              child: Row(
                                                children: [
                                                  Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF10B981)),
                                                  SizedBox(width: 8),
                                                  Text('Complete Onboarding'),
                                                ],
                                              ),
                                            ),
                                          ],
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
                    ),
          const SizedBox(height: 16),

          // Pagination Footer
          _buildPaginationFooter(isDark),
        ],
      ),
    );
  }

  Widget _buildPaginationFooter(bool isDark) {
    final currentPage = (_pagination['page'] as num?)?.toInt() ?? 1;
    final totalRecords = (_pagination['total_records'] as num?)?.toInt() ?? 0;
    final totalPages = (_pagination['total_pages'] as num?)?.toInt() ?? 1;

    final startIdx = totalRecords == 0 ? 0 : (currentPage - 1) * _pageSize + 1;
    final endIdx = math.min<int>(currentPage * _pageSize, totalRecords);

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 10,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 12,
          runSpacing: 6,
          children: [
            Text(
              'Showing $startIdx to $endIdx of $totalRecords new joiners',
              style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Rows per page: ',
                  style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
                const SizedBox(width: 4),
                DropdownButton<int>(
                  value: const [10, 25, 50, 100].contains(_pageSize) ? _pageSize : 10,
                  isDense: true,
                  underline: const SizedBox(),
                  dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  items: const [10, 25, 50, 100]
                      .map((n) => DropdownMenuItem<int>(value: n, child: Text('$n')))
                      .toList(),
                  onChanged: (val) {
                    if (val != null && val != _pageSize) {
                      setState(() => _pageSize = val);
                      _fetchRecords(page: 1);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left_rounded),
              onPressed: currentPage > 1 ? () => _fetchRecords(page: currentPage - 1) : null,
            ),
            ...List.generate(math.min<int>(5, totalPages), (idx) {
              final pageNum = idx + 1;
              final isCur = pageNum == currentPage;
              return InkWell(
                onTap: () => _fetchRecords(page: pageNum),
                child: Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: isCur ? const Color(0xFF4F46E5) : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: isCur ? const Color(0xFF4F46E5) : (isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1))),
                  ),
                  child: Center(
                    child: Text(
                      '$pageNum',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isCur ? FontWeight.bold : FontWeight.w500,
                        color: isCur ? Colors.white : (isDark ? Colors.white : const Color(0xFF0F172A)),
                      ),
                    ),
                  ),
                ),
              );
            }),
            IconButton(
              icon: const Icon(Icons.chevron_right_rounded),
              onPressed: currentPage < totalPages ? () => _fetchRecords(page: currentPage + 1) : null,
            ),
          ],
        ),
      ],
    );
  }

  // ==========================================================================
  // SECTION 6: ONBOARDING TASKS CARD
  // ==========================================================================
  Widget _buildTasksChecklistCard(bool isDark) {
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
              Text(
                'Onboarding Tasks',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              TextButton(
                onPressed: _openTasksDialog,
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                child: const Text(
                  'View All →',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4F46E5)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _recentTasks.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: Text('No active tasks.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))),
                )
              : Column(
                  children: _recentTasks.map((t) {
                    final isCompleted = t['status'] == 'Completed';
                    final isOverdue = t['status'] == 'Overdue';
                    final isInProgress = t['status'] == 'In Progress';

                    Color badgeBg;
                    Color badgeFg;
                    if (isCompleted) {
                      badgeBg = const Color(0xFF10B981).withValues(alpha: 0.1);
                      badgeFg = const Color(0xFF10B981);
                    } else if (isOverdue) {
                      badgeBg = const Color(0xFFEF4444).withValues(alpha: 0.1);
                      badgeFg = const Color(0xFFEF4444);
                    } else if (isInProgress) {
                      badgeBg = const Color(0xFF3B82F6).withValues(alpha: 0.1);
                      badgeFg = const Color(0xFF3B82F6);
                    } else {
                      badgeBg = const Color(0xFFF59E0B).withValues(alpha: 0.1);
                      badgeFg = const Color(0xFFF59E0B);
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () => _toggleRecentTask(t['id'].toString(), t['status'] ?? 'Pending'),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 20,
                              height: 20,
                              margin: const EdgeInsets.only(top: 2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isCompleted ? const Color(0xFF10B981) : Colors.transparent,
                                border: Border.all(
                                  color: isCompleted ? const Color(0xFF10B981) : (isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
                                  width: 1.5,
                                ),
                              ),
                              child: isCompleted ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  t['title'] ?? '',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                                    color: isCompleted ? const Color(0xFF94A3B8) : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Assigned to: ${t['assigned_team'] ?? 'HR Team'}   Due: ${t['due_date'] ?? 'On Joining'}',
                                  style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(6)),
                            child: Text(t['status'] ?? 'Pending', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeFg)),
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

  // ==========================================================================
  // SECTION 7: RECENT ACTIVITIES CARD
  // ==========================================================================
  Widget _buildRecentActivitiesCard(bool isDark) {
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
              Text(
                'Recent Activities',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              TextButton(
                onPressed: _openActivityLogDialog,
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                child: const Text('View All →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4F46E5))),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _recentActivities.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: Text('No activity logs.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))),
                )
              : Column(
                  children: _recentActivities.take(4).map((a) {
                    final action = a['action'] ?? 'Action';
                    IconData icon;
                    Color color;
                    if (action.contains('Joined')) {
                      icon = Icons.how_to_reg_rounded;
                      color = const Color(0xFF10B981);
                    } else if (action.contains('Document')) {
                      icon = Icons.description_outlined;
                      color = const Color(0xFF6366F1);
                    } else if (action.contains('Orientation')) {
                      icon = Icons.school_outlined;
                      color = const Color(0xFF10B981);
                    } else {
                      icon = Icons.computer_outlined;
                      color = const Color(0xFF0EA5E9);
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(icon, color: color, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(a['description'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                                const SizedBox(height: 2),
                                Text('Recent activity', style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
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

  // ==========================================================================
  // SECTION 8: ONBOARDING DOCUMENTS CARD
  // ==========================================================================
  Widget _buildOnboardingDocumentsCard(bool isDark) {
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
              Text(
                'Onboarding Documents',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              TextButton(
                onPressed: _openDocumentsDialog,
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8)),
                child: const Text('View All →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4F46E5))),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _recentDocuments.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: Text('No documents.', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)))),
                )
              : Column(
                  children: _recentDocuments.take(5).map((d) {
                    final status = d['status'] ?? 'Pending';
                    final isUploaded = status == 'Uploaded' || status == 'Verified';

                    return InkWell(
                      onTap: () {
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (ctx) => OnboardingDocumentViewerDialog(
                            document: d,
                            onDocumentUpdated: () {
                              _fetchDashboard();
                              _fetchRecords(page: _pagination['page'] ?? 1);
                            },
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(Icons.description_outlined, size: 16, color: Color(0xFF4F46E5)),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    d['document_name'] ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${d['candidate_name'] != null ? '${d['candidate_name']} • ' : ''}${d['required_for'] ?? 'All Employees'}',
                                    style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isUploaded ? const Color(0xFF10B981).withValues(alpha: 0.1) : const Color(0xFFF59E0B).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isUploaded ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: const Icon(Icons.visibility_outlined, size: 16, color: Color(0xFF4F46E5)),
                              tooltip: 'View / Preview Document',
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (ctx) => OnboardingDocumentViewerDialog(
                                    document: d,
                                    onDocumentUpdated: () {
                                      _fetchDashboard();
                                      _fetchRecords(page: _pagination['page'] ?? 1);
                                    },
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.upload_file_rounded, size: 16, color: Color(0xFF0EA5E9)),
                              tooltip: 'Upload Document (HR on behalf of Candidate)',
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (ctx) => OnboardingDocumentViewerDialog(
                                    document: d,
                                    onDocumentUpdated: () {
                                      _fetchDashboard();
                                      _fetchRecords(page: _pagination['page'] ?? 1);
                                    },
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ],
      ),
    );
  }

  // ==========================================================================
  // SECTION 9: GUIDE BANNER CARD
  // ==========================================================================
  Widget _buildGuideBannerCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13182C) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF4F46E5).withValues(alpha: isDark ? 0.12 : 0.04),
            const Color(0xFF8B5CF6).withValues(alpha: isDark ? 0.08 : 0.02),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.laptop_chromebook_rounded, color: Color(0xFF4F46E5), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Smooth Onboarding, Stronger Teams',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Automate, track and simplify your new hire onboarding process with EduSHAMIIT ERP.',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _openOnboardingGuideDialog(initialTab: 0),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4F46E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('View Onboarding Guide →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 14),
          const Text(
            '✦ "Great beginnings build great futures."',
            style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF6366F1), fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// CUSTOM DONUT CHART PAINTER FOR ONBOARDING BY DEPARTMENT
// ============================================================================
class _DepartmentDonutPainter extends CustomPainter {
  final List<dynamic> items;
  final int total;
  final bool isDark;

  _DepartmentDonutPainter({required this.items, required this.total, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const strokeWidth = 14.0;

    final bgPaint = Paint()
      ..color = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius - strokeWidth / 2, bgPaint);

    if (total == 0 || items.isEmpty) return;

    double startAngle = -math.pi / 2;

    for (final item in items) {
      final count = item['count'] as num? ?? 0;
      if (count <= 0) continue;
      final sweepAngle = (count / total) * 2 * math.pi;

      final paint = Paint()
        ..color = _getColorForDept(item['department'] ?? '')
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        sweepAngle - 0.05,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  Color _getColorForDept(String dept) {
    switch (dept) {
      case 'Academics':
        return const Color(0xFF4F46E5);
      case 'Administration':
        return const Color(0xFF0EA5E9);
      case 'IT / Technical':
        return const Color(0xFF06B6D4);
      case 'Finance':
        return const Color(0xFF10B981);
      case 'Transport':
        return const Color(0xFFEC4899);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  @override
  bool shouldRepaint(covariant _DepartmentDonutPainter oldDelegate) {
    return oldDelegate.items != items || oldDelegate.total != total;
  }
}
