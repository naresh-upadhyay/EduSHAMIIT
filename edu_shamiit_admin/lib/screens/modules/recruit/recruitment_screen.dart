import 'dart:async';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:edu_shamiit_core/services/api_service.dart';
import '../../../core/file_download_helper.dart';
import '../../../widgets/hr_management_tab_header.dart';
import 'widgets/candidate_detail_drawer.dart';
import 'widgets/create_job_dialog.dart';
import 'widgets/stage_details_dialog.dart';
import 'widgets/job_openings_list_dialog.dart';
import 'widgets/job_preview_dialog.dart';
import 'widgets/interview_feedback_dialog.dart';
import 'widgets/department_hiring_report_dialog.dart';
import 'widgets/recruitment_analytics_report_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

class RecruitmentScreen extends StatefulWidget {
  const RecruitmentScreen({super.key});

  @override
  State<RecruitmentScreen> createState() => _RecruitmentScreenState();
}

class _RecruitmentScreenState extends State<RecruitmentScreen> {
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  String? _errorMessage;
  Timer? _autoSyncTimer;

  // Data states
  Map<String, dynamic> _stats = {};
  Map<String, dynamic> _pipeline = {};
  Map<String, dynamic> _analytics = {};
  List<Map<String, dynamic>> _jobs = [];
  List<Map<String, dynamic>> _recentApplications = [];
  List<Map<String, dynamic>> _upcomingInterviews = [];
  String _interviewScope = 'upcoming'; // 'upcoming', 'today', 'completed', 'all'
  Map<String, dynamic> _interviewCounts = {};
  bool _isLoadingInterviews = false;
  int _interviewPage = 1;
  static const int _interviewPageSize = 4;

  // Job table state
  String _jobStatusFilter = 'Active'; // 'Active', 'Draft', 'All'
  String _jobDepartmentFilter = 'All';
  String _jobEmploymentTypeFilter = 'All';
  String _jobVisibilityFilter = 'All';
  final TextEditingController _jobSearchController = TextEditingController();
  int _jobCurrentPage = 1;
  int _jobPageSize = 5;

  @override
  void initState() {
    super.initState();
    _loadAllData();
    // Auto-sync recruitment data every 10 seconds for real-time live updates
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        _loadAllData(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    _jobSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllData({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final results = await Future.wait([
        _apiService.get('/recruitment/stats', useCache: false).catchError((e) {
          debugPrint('Error loading stats: $e');
          return <String, dynamic>{};
        }),
        _apiService.get('/recruitment/pipeline', useCache: false).catchError((e) {
          debugPrint('Error loading pipeline: $e');
          return <String, dynamic>{};
        }),
        _apiService.get('/recruitment/analytics', useCache: false).catchError((e) {
          debugPrint('Error loading analytics: $e');
          return <String, dynamic>{};
        }),
        _apiService.get('/recruitment/jobs?limit=500', useCache: false).catchError((e) {
          debugPrint('Error loading jobs: $e');
          return <String, dynamic>{};
        }),
        _apiService.get('/recruitment/candidates?limit=6', useCache: false).catchError((e) {
          debugPrint('Error loading candidates: $e');
          return <String, dynamic>{};
        }),
        _apiService.get('/recruitment/interviews?scope=$_interviewScope', useCache: false).catchError((e) {
          debugPrint('Error loading interviews: $e');
          return <String, dynamic>{};
        }),
      ]);

      final statsRes = results[0];
      final pipelineRes = results[1];
      final analyticsRes = results[2];
      final jobsRes = results[3];
      final candidatesRes = results[4];
      final interviewsRes = results[5];

      _stats = Map<String, dynamic>.from(statsRes['data'] ?? statsRes);
      _pipeline = Map<String, dynamic>.from(pipelineRes['data'] ?? pipelineRes);
      _analytics = Map<String, dynamic>.from(analyticsRes['data'] ?? analyticsRes);

      final List jItems = jobsRes['data'] ?? jobsRes['items'] ?? [];
      _jobs = jItems.map((e) => Map<String, dynamic>.from(e)).toList();

      final List cItems = candidatesRes['data'] ?? candidatesRes['items'] ?? [];
      _recentApplications = cItems.map((e) => Map<String, dynamic>.from(e)).toList();

      _interviewCounts = Map<String, dynamic>.from(interviewsRes['counts'] ?? {});
      final List itwList = interviewsRes['data'] ?? interviewsRes['items'] ?? [];
      _upcomingInterviews = itwList.map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (e) {
      debugPrint('Error loading recruitment data: $e');
      if (!silent) {
        _errorMessage = 'Failed to load recruitment dashboard. Please check server connection.';
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openStageDetails(
    String stage, {
    String? jobId,
    String? jobTitle,
    String? jobCode,
    int? candidateCount,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StageDetailsDialog(
        stage: stage,
        jobId: jobId,
        jobTitle: jobTitle,
        jobCode: jobCode,
        candidateCount: candidateCount ?? 0,
        onDataChanged: () => _loadAllData(silent: true),
      ),
    );
    if (mounted) {
      _loadAllData(silent: true);
    }
  }

  void _openJobOpeningsDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => JobOpeningsListDialog(
        initialJobs: _jobs,
        onDataChanged: () => _loadAllData(silent: true),
      ),
    );
  }

  void _openDepartmentHiringReportDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => DepartmentHiringReportDialog(
        departmentHiring: _analytics['department_hiring'] as List? ?? [],
        jobs: _jobs,
        onDataChanged: () => _loadAllData(silent: true),
      ),
    );
  }

  void _openRecruitmentAnalyticsReportDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => RecruitmentAnalyticsReportDialog(
        analytics: _analytics,
        jobs: _jobs,
        pipeline: _pipeline,
        applications: _recentApplications,
        onDataChanged: () => _loadAllData(silent: true),
      ),
    );
  }

  Future<void> _toggleJobPublic(Map<String, dynamic> j) async {
    final originalIsPublic = j['is_public'] == true;
    final newIsPublic = !originalIsPublic;

    setState(() {
      j['is_public'] = newIsPublic;
      final idx = _jobs.indexWhere((item) => item['id']?.toString() == j['id']?.toString());
      if (idx != -1) {
        _jobs[idx]['is_public'] = newIsPublic;
      }
    });

    try {
      final res = await _apiService.post('/recruitment/jobs/${j['id']}/toggle-public', {});
      final isNowPublic = res['data']?['is_public'] == true || res['is_public'] == true;
      if (mounted) {
        setState(() {
          j['is_public'] = isNowPublic;
          final idx = _jobs.indexWhere((item) => item['id']?.toString() == j['id']?.toString());
          if (idx != -1) {
            _jobs[idx]['is_public'] = isNowPublic;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isNowPublic ? 'Job is now published to Public Careers!' : 'Job unpublished from Public Careers.'),
            backgroundColor: isNowPublic ? const Color(0xFF16A34A) : const Color(0xFF475569),
            duration: const Duration(seconds: 2),
          ),
        );
        _loadAllData(silent: true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          j['is_public'] = originalIsPublic;
          final idx = _jobs.indexWhere((item) => item['id']?.toString() == j['id']?.toString());
          if (idx != -1) {
            _jobs[idx]['is_public'] = originalIsPublic;
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update visibility: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openCandidateDrawer(String candidateId) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'CandidateDrawer',
      barrierColor: Colors.black45,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim1, anim2) {
        return Align(
          alignment: Alignment.centerRight,
          child: CandidateDetailDrawer(
            candidateId: candidateId,
            onClose: () => Navigator.of(ctx).pop(),
            onActionCompleted: _loadAllData,
          ),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(anim1),
          child: child,
        );
      },
    );
  }

  void _openCreateJobDialog() {
    showDialog(
      context: context,
      builder: (ctx) => CreateJobDialog(onJobCreated: _loadAllData),
    );
  }

  Future<void> _exportData(String type) async {
    try {
      final res = await _apiService.getString('/recruitment/export/$type');
      if (mounted) {
        downloadFile(res, '${type}_export_${DateTime.now().millisecondsSinceEpoch}.csv');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$type export downloaded successfully (${res.length} bytes).'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  // Filtered jobs
  List<Map<String, dynamic>> get _filteredJobs {
    return _jobs.where((j) {
      final status = (j['publishing_status'] ?? '').toString();
      if (_jobStatusFilter == 'Active' && status != 'Active') return false;
      if (_jobStatusFilter == 'Draft' && status != 'Draft') return false;

      final dept = (j['department'] ?? '').toString();
      final isTeaching = dept == 'Teaching' || dept == 'Academics';
      final isAdmin = dept == 'Administration' || dept == 'Admin';

      if (_jobDepartmentFilter == 'Teaching' && !isTeaching) return false;
      if (_jobDepartmentFilter == 'Non-Teaching' && isTeaching) return false;
      if (_jobDepartmentFilter == 'Admin' && !isAdmin) return false;

      if (_jobEmploymentTypeFilter != 'All' && j['employment_type'] != _jobEmploymentTypeFilter) return false;
      if (_jobVisibilityFilter == 'Public' && j['is_public'] != true) return false;
      if (_jobVisibilityFilter == 'Internal' && j['is_public'] == true) return false;

      final query = _jobSearchController.text.trim().toLowerCase();
      if (query.isNotEmpty) {
        final title = (j['job_title'] ?? '').toString().toLowerCase();
        final code = (j['job_code'] ?? '').toString().toLowerCase();
        final loc = (j['location'] ?? '').toString().toLowerCase();
        final deptLower = dept.toLowerCase();
        if (!title.contains(query) && !code.contains(query) && !deptLower.contains(query) && !loc.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  void _openJobFiltersModal() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF13182C) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.tune_rounded, color: Color(0xFF4F46E5), size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Job Openings Filters',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Outfit',
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _jobStatusFilter = 'Active';
                            _jobDepartmentFilter = 'All';
                            _jobEmploymentTypeFilter = 'All';
                            _jobVisibilityFilter = 'All';
                            _jobCurrentPage = 1;
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text('Reset All', style: TextStyle(color: Color(0xFFEF4444))),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  const Text('Publishing Status', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['Active', 'Draft', 'All'].map((s) {
                      final sel = _jobStatusFilter == s;
                      return ChoiceChip(
                        label: Text(s),
                        selected: sel,
                        selectedColor: const Color(0xFF4F46E5),
                        labelStyle: TextStyle(
                          color: sel ? Colors.white : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                          fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (_) {
                          setModalState(() => _jobStatusFilter = s);
                          setState(() {
                            _jobStatusFilter = s;
                            _jobCurrentPage = 1;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text('Department', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ['All', 'Teaching', 'Non-Teaching', 'Admin'].map((d) {
                      final sel = _jobDepartmentFilter == d;
                      return ChoiceChip(
                        label: Text(d),
                        selected: sel,
                        selectedColor: const Color(0xFF4F46E5),
                        labelStyle: TextStyle(
                          color: sel ? Colors.white : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                          fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (_) {
                          setModalState(() => _jobDepartmentFilter = d);
                          setState(() {
                            _jobDepartmentFilter = d;
                            _jobCurrentPage = 1;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  const Text('Visibility & Careers Portal', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      {'label': 'All Visibilities', 'val': 'All'},
                      {'label': 'Public Careers Portal', 'val': 'Public'},
                      {'label': 'Internal Only', 'val': 'Internal'},
                    ].map((m) {
                      final val = m['val']!;
                      final sel = _jobVisibilityFilter == val;
                      return ChoiceChip(
                        label: Text(m['label']!),
                        selected: sel,
                        selectedColor: const Color(0xFF4F46E5),
                        labelStyle: TextStyle(
                          color: sel ? Colors.white : (isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155)),
                          fontWeight: sel ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (_) {
                          setModalState(() => _jobVisibilityFilter = val);
                          setState(() {
                            _jobVisibilityFilter = val;
                            _jobCurrentPage = 1;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4F46E5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090D1A) : const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Top Unified HR Management Header (Active Tab: Recruitment)
            HRManagementHeader(
              activeTab: HRTab.recruitment,
              title: 'Recruitment',
              subtitle: 'Find, hire and build your best team.',
              icon: Icons.people_alt_rounded,
              onRefresh: _loadAllData,
              isRefreshing: _isLoading,
              actions: [
                SizedBox(
                  height: 38,
                  child: OutlinedButton.icon(
                    onPressed: () => _openStageDetails('Applied'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: Icon(Icons.search, size: 16, color: isDark ? const Color(0xFF818CF8) : const Color(0xFF475569)),
                    label: Text('Candidate Search', style: TextStyle(color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155), fontWeight: FontWeight.w500, fontFamily: 'Inter', fontSize: 13)),
                  ),
                ),
                SizedBox(
                  height: 38,
                  child: OutlinedButton.icon(
                    onPressed: () => _exportData('jobs'),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: Icon(Icons.bar_chart_rounded, size: 16, color: isDark ? const Color(0xFF818CF8) : const Color(0xFF475569)),
                    label: Text('Reports', style: TextStyle(color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155), fontWeight: FontWeight.w500, fontFamily: 'Inter', fontSize: 13)),
                  ),
                ),
                SizedBox(
                  height: 38,
                  child: ElevatedButton.icon(
                    onPressed: _openCreateJobDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.add, size: 16, color: Colors.white),
                    label: const Text('Create Job Opening', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontFamily: 'Inter', fontSize: 13)),
                  ),
                ),
                SizedBox(
                  height: 38,
                  width: 38,
                  child: PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
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
                      if (val == 'export_jobs') _exportData('jobs');
                      if (val == 'export_candidates') _exportData('candidates');
                      if (val == 'refresh') _loadAllData();
                    },
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(value: 'export_jobs', child: Text('Export Jobs CSV')),
                      const PopupMenuItem(value: 'export_candidates', child: Text('Export Candidates CSV')),
                      const PopupMenuItem(value: 'refresh', child: Text('Refresh Data')),
                    ],
                  ),
                ),
              ],
            ),

            // Main Content Area
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
                  : _errorMessage != null
                      ? _buildErrorView()
                      : RefreshIndicator(
                          onRefresh: _loadAllData,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // 1. Full-width Recruitment Pipeline (placed at the top where the removed element was)
                                _buildRecruitmentPipelineCard(),
                                const SizedBox(height: 20),

                                // 2. Active Job Openings + Upcoming Interviews & Department Hiring
                                _buildJobsAndInterviewsRow(),
                                const SizedBox(height: 20),

                                // 3. Recent Applications + Analytics
                                _buildBottomRow(),
                                const SizedBox(height: 30),
                              ],
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off_rounded, size: 48, color: Color(0xFFEF4444)),
          const SizedBox(height: 14),
          Text(_errorMessage!, style: const TextStyle(fontSize: 15, color: Color(0xFF475569))),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadAllData,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry Connection'),
          ),
        ],
      ),
    );
  }



  // ===========================================================================
  // 1. RECRUITMENT PIPELINE (FULL-WIDTH AT TOP)
  // ===========================================================================
  Widget _buildRecruitmentPipelineCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [boxUnderShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.account_tree_outlined, size: 18, color: Color(0xFF4F46E5)),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Recruitment Pipeline',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  children: [
                    Text('Last 30 Days', style: TextStyle(fontSize: 12, color: Color(0xFF475569))),
                    SizedBox(width: 4),
                    Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF475569)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Pipeline Blocks
          _buildPipelineBlocks(),
        ],
      ),
    );
  }

  Widget _buildPipelineBlocks() {
    final stages = _analytics['pipeline_stages'] as List? ?? _pipeline['pipeline'] as List? ?? [];
    Map<String, dynamic> stageData(String name) {
      for (var s in stages) {
        if (s['stage'] == name) return s;
      }
      return {'count': _pipeline[name] ?? 0, 'conversion_rate': 0.0};
    }

    String convRate(String stageName, String defaultVal) {
      final s = stageData(stageName);
      if (s['conversion_rate'] != null) {
        return '${s['conversion_rate']}%';
      }
      return defaultVal;
    }

    final jobOpeningsCount = _stats['active_positions'] ?? _stats['kpis']?['active_jobs'] ?? _jobs.where((j) => j['publishing_status'] == 'Active').length;
    final appliedCount = _pipeline['Applied'] ?? _pipeline['Applications'] ?? stageData('Applied')['count'] ?? stageData('Applications')['count'] ?? 0;
    final scrCount = _pipeline['Screening'] ?? stageData('Screening')['count'] ?? 0;
    final shoCount = _pipeline['Shortlisted'] ?? stageData('Shortlisted')['count'] ?? _stats['shortlisted'] ?? 0;
    final assCount = _pipeline['Assessment'] ?? stageData('Assessment')['count'] ?? 0;
    final itwCount = _pipeline['Interview'] ?? stageData('Interview')['count'] ?? _stats['interviews'] ?? 0;
    final selCount = _pipeline['Selected'] ?? stageData('Selected')['count'] ?? 0;
    final offCount = _pipeline['Offer'] ?? stageData('Offer')['count'] ?? _stats['offers_pending'] ?? 0;
    final hrdCount = _pipeline['Hired'] ?? stageData('Hired')['count'] ?? _stats['hired'] ?? 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStageBlock(
                  title: 'Job Openings',
                  count: '$jobOpeningsCount',
                  conversion: '100%',
                  icon: Icons.work_outline_rounded,
                  color: const Color(0xFF4F46E5),
                  onTap: _openJobOpeningsDialog,
                ),
                _buildPipelineArrow(),
                _buildStageBlock(
                  title: 'Applied',
                  count: '$appliedCount',
                  conversion: convRate('Applied', '100%'),
                  icon: Icons.contact_page_outlined,
                  color: const Color(0xFF0284C7),
                  onTap: () => _openStageDetails('Applied'),
                ),
                _buildPipelineArrow(),
                _buildStageBlock(
                  title: 'Screening',
                  count: '$scrCount',
                  conversion: convRate('Screening', '88.7%'),
                  icon: Icons.filter_alt_outlined,
                  color: const Color(0xFFF59E0B),
                  onTap: () => _openStageDetails('Screening'),
                ),
                _buildPipelineArrow(),
                _buildStageBlock(
                  title: 'Shortlisted',
                  count: '$shoCount',
                  conversion: convRate('Shortlisted', '60.5%'),
                  icon: Icons.assignment_turned_in_outlined,
                  color: const Color(0xFF0D9488),
                  onTap: () => _openStageDetails('Shortlisted'),
                ),
                _buildPipelineArrow(),
                _buildStageBlock(
                  title: 'Assessment',
                  count: '$assCount',
                  conversion: convRate('Assessment', '55.8%'),
                  icon: Icons.quiz_outlined,
                  color: const Color(0xFF10B981),
                  onTap: () => _openStageDetails('Assessment'),
                ),
                _buildPipelineArrow(),
                _buildStageBlock(
                  title: 'Interview',
                  count: '$itwCount',
                  conversion: convRate('Interview', '40%'),
                  icon: Icons.forum_outlined,
                  color: const Color(0xFFEC4899),
                  onTap: () => _openStageDetails('Interview'),
                ),
                _buildPipelineArrow(),
                _buildStageBlock(
                  title: 'Selected Candidates',
                  count: '$selCount',
                  conversion: convRate('Selected', '25%'),
                  icon: Icons.verified_outlined,
                  color: const Color(0xFF6366F1),
                  onTap: () => _openStageDetails('Selected'),
                ),
                _buildPipelineArrow(),
                _buildStageBlock(
                  title: 'Offer',
                  count: '$offCount',
                  conversion: convRate('Offer', '75%'),
                  icon: Icons.local_offer_outlined,
                  color: const Color(0xFF8B5CF6),
                  onTap: () => _openStageDetails('Offer'),
                ),
                _buildPipelineArrow(),
                _buildStageBlock(
                  title: 'Hired',
                  count: '$hrdCount',
                  conversion: convRate('Hired', '88.7%'),
                  icon: Icons.how_to_reg_outlined,
                  color: const Color(0xFF059669),
                  onTap: () => _openStageDetails('Hired'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPipelineArrow() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 2),
      child: Icon(Icons.arrow_forward_rounded, color: Color(0xFFCBD5E1), size: 16),
    );
  }

  Widget _buildStageBlock({
    required String title,
    required String count,
    required String conversion,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 108,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 28,
              child: Center(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              count,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                conversion,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildDepartmentHiringBars() {
    final List apiDepts = _analytics['department_hiring'] as List? ?? [];
    final List depts = apiDepts.isNotEmpty
        ? apiDepts.map((d) => {
            'name': d['department'] ?? 'Other',
            'count': d['count'] ?? 0,
            'pct': ((d['percentage'] as num?)?.toDouble() ?? 0.0) / 100.0,
          }).toList()
        : [
            {'name': 'Teaching', 'count': 12, 'pct': 0.375},
            {'name': 'Administration', 'count': 8, 'pct': 0.250},
            {'name': 'IT', 'count': 5, 'pct': 0.156},
            {'name': 'Transport', 'count': 4, 'pct': 0.125},
            {'name': 'Finance', 'count': 2, 'pct': 0.063},
            {'name': 'Others', 'count': 1, 'pct': 0.031},
          ];

    final colors = [
      const Color(0xFF4F46E5),
      const Color(0xFF8B5CF6),
      const Color(0xFF0284C7),
      const Color(0xFFF59E0B),
      const Color(0xFF10B981),
      const Color(0xFF64748B),
    ];

    return Column(
      children: List.generate(depts.length, (idx) {
        final d = depts[idx];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(d['name'], style: const TextStyle(fontSize: 11, color: Color(0xFF334155), fontWeight: FontWeight.w500)),
                  Text('${d['count']} (${(d['pct'] * 100).toStringAsFixed(1)}%)', style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: d['pct'],
                  backgroundColor: const Color(0xFFF1F5F9),
                  valueColor: AlwaysStoppedAnimation<Color>(colors[idx % colors.length]),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  // ===========================================================================
  // 2. ACTIVE JOB OPENINGS + UPCOMING INTERVIEWS & DEPARTMENT HIRING
  // ===========================================================================
  Widget _buildJobsAndInterviewsRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 960) {
          return Column(
            children: [
              _buildActiveJobsCard(),
              const SizedBox(height: 20),
              _buildUpcomingInterviewsCard(),
              const SizedBox(height: 20),
              _buildDepartmentHiringCard(),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Active Job Openings Table (Left 65%)
            Expanded(
              flex: 65,
              child: _buildActiveJobsCard(),
            ),
            const SizedBox(width: 16),

            // Upcoming Interviews & Department-wise Hiring (Right 35%)
            Expanded(
              flex: 35,
              child: Column(
                children: [
                  _buildUpcomingInterviewsCard(),
                  const SizedBox(height: 16),
                  _buildDepartmentHiringCard(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildActiveJobsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [boxUnderShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header + Search + Filter tabs
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Text(
                _jobStatusFilter == 'Active'
                    ? 'Active Job Openings'
                    : (_jobStatusFilter == 'Draft' ? 'Draft Job Openings' : 'All Job Openings'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 220,
                    height: 36,
                    child: TextField(
                      controller: _jobSearchController,
                      onChanged: (v) => setState(() => _jobCurrentPage = 1),
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Search title, code, dept, loc...',
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: _jobSearchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _jobSearchController.clear();
                                  setState(() => _jobCurrentPage = 1);
                                },
                              )
                            : null,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _openJobFiltersModal,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      side: BorderSide(
                        color: (_jobStatusFilter != 'Active' || _jobDepartmentFilter != 'All' || _jobVisibilityFilter != 'All')
                            ? const Color(0xFF4F46E5)
                            : const Color(0xFFCBD5E1),
                      ),
                      backgroundColor: (_jobStatusFilter != 'Active' || _jobDepartmentFilter != 'All' || _jobVisibilityFilter != 'All')
                          ? const Color(0xFF4F46E5).withValues(alpha: 0.08)
                          : Colors.transparent,
                    ),
                    icon: Icon(
                      Icons.tune_rounded,
                      size: 16,
                      color: (_jobStatusFilter != 'Active' || _jobDepartmentFilter != 'All' || _jobVisibilityFilter != 'All')
                          ? const Color(0xFF4F46E5)
                          : const Color(0xFF475569),
                    ),
                    label: Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: (_jobStatusFilter != 'Active' || _jobDepartmentFilter != 'All' || _jobVisibilityFilter != 'All')
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: (_jobStatusFilter != 'Active' || _jobDepartmentFilter != 'All' || _jobVisibilityFilter != 'All')
                            ? const Color(0xFF4F46E5)
                            : const Color(0xFF334155),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Status subtabs (Active, Draft, All)
          Builder(builder: (context) {
            final activeCount = _jobs.where((j) => j['publishing_status'] == 'Active').length;
            final draftCount = _jobs.where((j) => j['publishing_status'] == 'Draft').length;
            final relevantJobs = _jobs.where((j) {
              if (_jobStatusFilter == 'Active') return j['publishing_status'] == 'Active';
              if (_jobStatusFilter == 'Draft') return j['publishing_status'] == 'Draft';
              return true;
            }).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildJobStatusPill('Active ($activeCount)', 'Active'),
                      const SizedBox(width: 8),
                      _buildJobStatusPill('Draft ($draftCount)', 'Draft'),
                      const SizedBox(width: 8),
                      _buildJobStatusPill('All (${_jobs.length})', 'All'),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Department filter subtabs
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildJobFilterChip('All (${relevantJobs.length})', 'All'),
                      const SizedBox(width: 8),
                      _buildJobFilterChip(
                        'Teaching (${relevantJobs.where((j) => j['department'] == 'Teaching' || j['department'] == 'Academics').length})',
                        'Teaching',
                      ),
                      const SizedBox(width: 8),
                      _buildJobFilterChip(
                        'Non-Teaching (${relevantJobs.where((j) => j['department'] != 'Teaching' && j['department'] != 'Academics' && j['department'] != 'Administration').length})',
                        'Non-Teaching',
                      ),
                      const SizedBox(width: 8),
                      _buildJobFilterChip(
                        'Admin (${relevantJobs.where((j) => j['department'] == 'Administration').length})',
                        'Admin',
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
          const SizedBox(height: 16),

          // Data Table
          _buildJobTable(),
        ],
      ),
    );
  }

  Widget _buildJobStatusPill(String label, String value) {
    final isSelected = _jobStatusFilter == value;
    return InkWell(
      onTap: () => setState(() {
        _jobStatusFilter = value;
        _jobCurrentPage = 1;
      }),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingInterviewsCard() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    int validUpcomingCount = 0;
    int validTodayCount = 0;
    int validCompletedCount = 0;

    for (final itw in _upcomingInterviews) {
      final status = (itw['status'] ?? '').toString();
      if (status == 'Cancelled' || status == 'Rejected') continue;
      if (itw['scheduled_date'] == null) continue;
      try {
        final d = DateTime.parse(itw['scheduled_date'].toString().substring(0, 10));
        final dateOnly = DateTime(d.year, d.month, d.day);
        if (dateOnly.isBefore(today) || status == 'Completed') {
          validCompletedCount++;
        } else if (dateOnly.isAtSameMomentAs(today) && status != 'Completed') {
          validTodayCount++;
          validUpcomingCount++;
        } else if (dateOnly.isAfter(today) && status != 'Completed') {
          validUpcomingCount++;
        }
      } catch (_) {}
    }

    final upcomingCount = _interviewCounts['upcoming_count'] ?? validUpcomingCount;
    final todayCount = _interviewCounts['today_count'] ?? validTodayCount;
    final completedCount = _interviewCounts['completed_count'] ?? validCompletedCount;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [boxUnderShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.event_note_rounded, size: 18, color: Color(0xFF4F46E5)),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Interviews',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      Text(
                        _interviewScope == 'today'
                            ? '$todayCount scheduled for today'
                            : _interviewScope == 'completed'
                                ? '$completedCount completed rounds'
                                : '$upcomingCount scheduled upcoming',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  // Schedule button
                  ElevatedButton.icon(
                    onPressed: () => _openStageDetails('Interview'),
                    icon: const Icon(Icons.add_rounded, size: 14),
                    label: const Text('Schedule'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      minimumSize: const Size(0, 32),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Refresh button
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, size: 18, color: Color(0xFF64748B)),
                    tooltip: 'Refresh Interviews',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () => _changeInterviewScope(_interviewScope),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Segmented Scope Filter Tabs
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                _buildInterviewScopeTab('Upcoming', 'upcoming', upcomingCount),
                _buildInterviewScopeTab('Today', 'today', todayCount),
                _buildInterviewScopeTab('Completed', 'completed', completedCount),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_isLoadingInterviews) ...[
            const ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(4)),
              child: LinearProgressIndicator(
                minHeight: 3,
                backgroundColor: Color(0xFFEEF2FF),
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
              ),
            ),
            const SizedBox(height: 12),
          ],

          _buildUpcomingInterviewsList(),
        ],
      ),
    );
  }

  Widget _buildInterviewScopeTab(String label, String scopeKey, dynamic count) {
    final isSelected = _interviewScope == scopeKey;
    return Expanded(
      child: InkWell(
        onTap: () {
          if (_interviewScope != scopeKey) {
            _changeInterviewScope(scopeKey);
          }
        },
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? const Color(0xFF1E293B) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF4F46E5).withValues(alpha: 0.12)
                      : const Color(0xFFCBD5E1).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDepartmentHiringCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [boxUnderShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Department-wise Hiring', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              InkWell(
                onTap: _openDepartmentHiringReportDialog,
                child: const Text('View Report →', style: TextStyle(fontSize: 12, color: Color(0xFF4F46E5), fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildDepartmentHiringBars(),
        ],
      ),
    );
  }

  Widget _buildJobFilterChip(String label, String value) {
    final isSelected = _jobDepartmentFilter == value;
    return InkWell(
      onTap: () => setState(() {
        _jobDepartmentFilter = value;
        _jobCurrentPage = 1;
      }),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4F46E5).withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFFE2E8F0)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  Widget _buildJobTable() {
    final filtered = _filteredJobs;
    final totalPages = filtered.isEmpty ? 1 : ((filtered.length - 1) ~/ _jobPageSize) + 1;
    if (_jobCurrentPage > totalPages) {
      _jobCurrentPage = totalPages;
    }
    if (_jobCurrentPage < 1) {
      _jobCurrentPage = 1;
    }
    final startIndex = (_jobCurrentPage - 1) * _jobPageSize;
    final paged = filtered.skip(startIndex).take(_jobPageSize).toList();

    if (paged.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: const Text('No job openings found matching the criteria.', style: TextStyle(color: Color(0xFF94A3B8))),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            const minTableWidth = 760.0;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: constraints.maxWidth > minTableWidth ? constraints.maxWidth : minTableWidth,
                ),
                child: Table(
                  columnWidths: const {
                    0: FlexColumnWidth(2.6),
                    1: FlexColumnWidth(1.5),
                    2: FlexColumnWidth(0.9),
                    3: FlexColumnWidth(0.9),
                    4: FlexColumnWidth(1.2),
                    5: FlexColumnWidth(1.2),
                    6: FlexColumnWidth(1.4),
                    7: FlexColumnWidth(1.3),
                  },
                  children: [
                    // Header
                    TableRow(
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.5)),
                      ),
                      children: [
                        _tableHeader('Job Title'),
                        _tableHeader('Department'),
                        _tableHeader('Vacancies'),
                        _tableHeader('Applicants'),
                        _tableHeader('Posted On'),
                        _tableHeader('Closing Date'),
                        _tableHeader('Status & Visibility'),
                        _tableHeader('Actions'),
                      ],
                    ),

                    // Rows
                    ...paged.map((j) {
                      final title = j['job_title'] ?? 'Role';
                      final dept = j['department'] ?? 'Dept';
                      final vacancies = j['vacancies'] ?? 1;
                      final applicants = (j['total_applicants'] ?? j['applicant_count'] ?? 0) as int;
                      final posted = j['job_posting_date'] != null
                          ? DateFormat('dd MMM yyyy').format(DateTime.parse(j['job_posting_date']))
                          : '10 May 2026';
                      final closing = j['application_deadline'] != null
                          ? DateFormat('dd MMM yyyy').format(DateTime.parse(j['application_deadline']))
                          : '25 May 2026';
                      final status = j['publishing_status'] ?? 'Active';
                      final isPublic = j['is_public'] == true;
                      final slug = j['slug'] ?? j['id']?.toString() ?? '';

                      return TableRow(
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                        ),
                        children: [
                          // Title + icon
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(Icons.work_outline_rounded, size: 14, color: Color(0xFF4F46E5)),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    title,
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Department
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(dept, style: const TextStyle(fontSize: 12, color: Color(0xFF475569))),
                          ),

                          // Vacancies
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text('$vacancies', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                          ),

                          // Applicants
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: InkWell(
                              onTap: () => _openStageDetails(
                                'All',
                                jobId: j['id']?.toString(),
                                jobTitle: title,
                                jobCode: j['job_code']?.toString(),
                                candidateCount: applicants,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: applicants > 0 ? const Color(0xFF4F46E5).withValues(alpha: 0.1) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.people_alt_outlined,
                                      size: 13,
                                      color: applicants > 0 ? const Color(0xFF4F46E5) : const Color(0xFF94A3B8),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$applicants',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: applicants > 0 ? const Color(0xFF4F46E5) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Posted On
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(posted, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          ),

                          // Closing Date
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(closing, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                          ),

                          // Status & Visibility Badge
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: status == 'Active' ? const Color(0xFFDCFCE7) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    status,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: status == 'Active' ? const Color(0xFF16A34A) : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isPublic ? Icons.public : Icons.lock_outline,
                                      size: 11,
                                      color: isPublic ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      isPublic ? 'Public' : 'Internal',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: isPublic ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Actions
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Tooltip(
                                  message: 'View Candidates for this Job',
                                  child: InkWell(
                                    onTap: () => _openStageDetails(
                                      'All',
                                      jobId: j['id']?.toString(),
                                      jobTitle: title,
                                      jobCode: j['job_code']?.toString(),
                                      candidateCount: applicants,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                    child: const Padding(
                                      padding: EdgeInsets.all(4),
                                      child: Icon(Icons.visibility_outlined, size: 16, color: Color(0xFF64748B)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Tooltip(
                                  message: isPublic ? 'Make Private' : 'Publish to Careers',
                                  child: InkWell(
                                    onTap: () => _toggleJobPublic(j),
                                    borderRadius: BorderRadius.circular(4),
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Icon(
                                        isPublic ? Icons.public : Icons.public_off,
                                        size: 16,
                                        color: isPublic ? const Color(0xFF2563EB) : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, size: 16, color: Color(0xFF64748B)),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onSelected: (action) async {
                                      final messenger = ScaffoldMessenger.of(context);
                                      if (action == 'preview') {
                                        showDialog(
                                          context: context,
                                          builder: (ctx) => JobPreviewDialog(
                                            job: j,
                                            onJobChanged: () => _loadAllData(silent: true),
                                          ),
                                        );
                                      } else if (action == 'copy_link') {
                                        final publicUrl = '${Uri.base.origin}/careers/jobs/$slug';
                                        await Clipboard.setData(ClipboardData(text: publicUrl));
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              isPublic
                                                  ? 'Public job link copied: $publicUrl'
                                                  : 'Job link copied: $publicUrl (Note: Job is currently marked Private. Set to Public for public candidates to view).',
                                            ),
                                            backgroundColor: isPublic ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                                          ),
                                        );
                                      } else if (action == 'toggle_public') {
                                        if (status == 'Draft' && !isPublic) {
                                          messenger.showSnackBar(
                                            const SnackBar(
                                              content: Text('Draft jobs cannot be published to the public Careers portal. Please activate the job first.'),
                                              backgroundColor: Color(0xFFD97706),
                                            ),
                                          );
                                          return;
                                        }
                                        await _toggleJobPublic(j);
                                      } else if (action == 'duplicate') {
                                        try {
                                          await _apiService.post('/recruitment/jobs/${j['id']}/duplicate', {});
                                          if (mounted) {
                                            messenger.showSnackBar(
                                              const SnackBar(content: Text('Job opening duplicated as Draft.'), backgroundColor: Color(0xFF16A34A)),
                                            );
                                            setState(() => _jobStatusFilter = 'Draft');
                                            _loadAllData(silent: true);
                                          }
                                        } catch (e) {
                                          if (mounted) {
                                            messenger.showSnackBar(
                                              SnackBar(content: Text('Duplicate failed: $e'), backgroundColor: Colors.red),
                                            );
                                          }
                                        }
                                      } else if (action == 'pause') {
                                        final isPaused = status == 'Paused';
                                        final actionName = isPaused ? 'activate' : 'pause';
                                        setState(() {
                                          j['publishing_status'] = isPaused ? 'Active' : 'Paused';
                                        });
                                        try {
                                          await _apiService.post('/recruitment/jobs/${j['id']}/$actionName', {});
                                          if (mounted) {
                                            messenger.showSnackBar(
                                              SnackBar(
                                                content: Text(isPaused ? 'Job opening activated successfully.' : 'Job opening paused successfully.'),
                                                backgroundColor: const Color(0xFF16A34A),
                                              ),
                                            );
                                            _loadAllData(silent: true);
                                          }
                                        } catch (e) {
                                          if (mounted) {
                                            messenger.showSnackBar(
                                              SnackBar(content: Text('Action failed: $e'), backgroundColor: Colors.red),
                                            );
                                            _loadAllData(silent: true);
                                          }
                                        }
                                      } else if (action == 'delete') {
                                        final confirmed = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: const Text('Delete Job Opening?'),
                                            content: Text('Are you sure you want to delete "$title"? This action cannot be undone.'),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                                                onPressed: () => Navigator.pop(ctx, true),
                                                child: const Text('Delete', style: TextStyle(color: Colors.white)),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirmed == true) {
                                          setState(() {
                                            _jobs.removeWhere((item) => item['id'] == j['id']);
                                          });
                                          try {
                                            await _apiService.delete('/recruitment/jobs/${j['id']}');
                                            if (mounted) {
                                              messenger.showSnackBar(
                                                const SnackBar(content: Text('Job opening deleted successfully.'), backgroundColor: Color(0xFFEF4444)),
                                              );
                                              _loadAllData(silent: true);
                                            }
                                          } catch (e) {
                                            if (mounted) {
                                              messenger.showSnackBar(
                                                SnackBar(content: Text('Delete failed: $e'), backgroundColor: Colors.red),
                                              );
                                              _loadAllData(silent: true);
                                            }
                                          }
                                        }
                                      }
                                    },
                                    itemBuilder: (ctx) {
                                      final isPaused = status == 'Paused';
                                      return [
                                        const PopupMenuItem(
                                          value: 'preview',
                                          child: Row(
                                            children: [
                                              Icon(Icons.remove_red_eye_outlined, size: 15, color: Color(0xFF4F46E5)),
                                              SizedBox(width: 8),
                                              Text('Preview Job Details'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'copy_link',
                                          child: Row(
                                            children: [
                                              Icon(Icons.link, size: 15, color: Color(0xFF0D9488)),
                                              SizedBox(width: 8),
                                              Text('Copy Public Link'),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'toggle_public',
                                          child: Row(
                                            children: [
                                              Icon(isPublic ? Icons.visibility_off : Icons.visibility, size: 15, color: const Color(0xFFD97706)),
                                              const SizedBox(width: 8),
                                              Text(isPublic ? 'Make Private' : 'Publish to Careers'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuDivider(),
                                        const PopupMenuItem(
                                          value: 'duplicate',
                                          child: Row(
                                            children: [
                                              Icon(Icons.copy_rounded, size: 15, color: Color(0xFF64748B)),
                                              SizedBox(width: 8),
                                              Text('Duplicate'),
                                            ],
                                          ),
                                        ),
                                        PopupMenuItem(
                                          value: 'pause',
                                          child: Row(
                                            children: [
                                              Icon(
                                                isPaused ? Icons.play_circle_outline : Icons.pause_circle_outline,
                                                size: 15,
                                                color: isPaused ? const Color(0xFF10B981) : const Color(0xFFD97706),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(isPaused ? 'Activate Job' : 'Pause Job'),
                                            ],
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'delete',
                                          child: Row(
                                            children: [
                                              Icon(Icons.delete_outline, size: 15, color: Color(0xFFEF4444)),
                                              SizedBox(width: 8),
                                              Text('Delete Job', style: TextStyle(color: Color(0xFFEF4444))),
                                            ],
                                          ),
                                        ),
                                      ];
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),

        // Pagination row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                filtered.isEmpty
                    ? 'Showing 0 of 0 job openings'
                    : 'Showing ${startIndex + 1} to ${startIndex + paged.length} of ${filtered.length} job openings',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Records Per Page Dropdown
                Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _jobPageSize,
                      isDense: true,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF1E293B), fontWeight: FontWeight.w600),
                      items: const [
                        DropdownMenuItem(value: 5, child: Text('5 per page')),
                        DropdownMenuItem(value: 10, child: Text('10 per page')),
                        DropdownMenuItem(value: 20, child: Text('20 per page')),
                        DropdownMenuItem(value: 50, child: Text('50 per page')),
                      ],
                      onChanged: (newSize) {
                        if (newSize != null && newSize != _jobPageSize) {
                          setState(() {
                            _jobPageSize = newSize;
                            _jobCurrentPage = 1;
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Navigation Controls
                IconButton(
                  icon: const Icon(Icons.first_page_rounded, size: 18),
                  tooltip: 'First Page',
                  onPressed: _jobCurrentPage > 1 ? () => setState(() => _jobCurrentPage = 1) : null,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded, size: 20),
                  tooltip: 'Previous Page',
                  onPressed: _jobCurrentPage > 1 ? () => setState(() => _jobCurrentPage--) : null,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '$_jobCurrentPage of $totalPages',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF4F46E5)),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded, size: 20),
                  tooltip: 'Next Page',
                  onPressed: _jobCurrentPage < totalPages
                      ? () => setState(() => _jobCurrentPage++)
                      : null,
                ),
                IconButton(
                  icon: const Icon(Icons.last_page_rounded, size: 18),
                  tooltip: 'Last Page',
                  onPressed: _jobCurrentPage < totalPages
                      ? () => setState(() => _jobCurrentPage = totalPages)
                      : null,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _tableHeader(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
      ),
    );
  }

  Future<void> _changeInterviewScope(String scope) async {
    setState(() {
      _interviewScope = scope;
      _interviewPage = 1;
      _isLoadingInterviews = true;
    });
    try {
      final res = await _apiService.get('/recruitment/interviews?scope=$scope', useCache: false);
      if (res['counts'] != null) {
        _interviewCounts = Map<String, dynamic>.from(res['counts']);
      }
      final List itwList = res['data'] ?? res['items'] ?? [];
      if (mounted) {
        setState(() {
          _upcomingInterviews = itwList.map((e) => Map<String, dynamic>.from(e)).toList();
          _isLoadingInterviews = false;
        });
      }
    } catch (e) {
      debugPrint('Error changing interview scope: $e');
      if (mounted) {
        setState(() => _isLoadingInterviews = false);
      }
    }
  }

  Future<void> _joinMeeting(String? link) async {
    if (link == null || link.trim().isEmpty) return;
    var urlStr = link.trim();
    if (!urlStr.startsWith('http://') && !urlStr.startsWith('https://')) {
      urlStr = 'https://$urlStr';
    }
    try {
      final uri = Uri.parse(urlStr);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open meeting link: $urlStr'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening link: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openInterviewFeedback(Map<String, dynamic> itw) {
    final interviewId = itw['id']?.toString() ?? '';
    final roundTitle = itw['interview_round']?.toString() ?? itw['round']?.toString() ?? 'Interview Round';
    final candName = itw['candidate_name']?.toString() ?? 'Candidate';

    if (interviewId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Interview record has no ID.'), backgroundColor: Colors.red),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => InterviewFeedbackDialog(
        interviewId: interviewId,
        roundTitle: roundTitle,
        candidateName: candName,
        onFeedbackSubmitted: () {
          _changeInterviewScope(_interviewScope);
          _loadAllData(silent: true);
        },
      ),
    );
  }  Widget _buildUpcomingInterviewsList() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Filter strictly based on current date and scope
    final filteredList = _upcomingInterviews.where((itw) {
      final status = (itw['status'] ?? '').toString();
      if (status == 'Cancelled' || status == 'Rejected') return false;
      if (itw['scheduled_date'] == null) return false;

      try {
        final d = DateTime.parse(itw['scheduled_date'].toString().substring(0, 10));
        final dateOnly = DateTime(d.year, d.month, d.day);

        if (_interviewScope == 'today') {
          return dateOnly.isAtSameMomentAs(today) && status != 'Completed';
        } else if (_interviewScope == 'completed') {
          return dateOnly.isBefore(today) || status == 'Completed';
        } else {
          // 'upcoming': strictly today or future, and not completed
          return !dateOnly.isBefore(today) && status != 'Completed';
        }
      } catch (_) {
        return false;
      }
    }).toList();

    if (filteredList.isEmpty && !_isLoadingInterviews) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.event_available_outlined, size: 32, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 12),
            Text(
              _interviewScope == 'today'
                  ? 'No Interviews Scheduled Today'
                  : _interviewScope == 'completed'
                      ? 'No Completed Interviews Yet'
                      : 'No Upcoming Interviews',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 4),
            Text(
              _interviewScope == 'today'
                  ? 'There are no interview rounds scheduled for today.'
                  : 'All caught up! Schedule a new interview round from candidate pipeline.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () => _openStageDetails('Interview'),
              icon: const Icon(Icons.add_rounded, size: 14),
              label: const Text('Schedule Interview'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF4F46E5),
                side: const BorderSide(color: Color(0xFFC7D2FE)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    // Keep it optimum: paginate up to _interviewPageSize items
    final totalPages = filteredList.isEmpty ? 1 : ((filteredList.length - 1) ~/ _interviewPageSize) + 1;
    if (_interviewPage > totalPages) {
      _interviewPage = totalPages;
    }
    if (_interviewPage < 1) {
      _interviewPage = 1;
    }
    final startIndex = (_interviewPage - 1) * _interviewPageSize;
    final endIndex = (startIndex + _interviewPageSize) > filteredList.length ? filteredList.length : (startIndex + _interviewPageSize);
    final pagedList = filteredList.skip(startIndex).take(_interviewPageSize).toList();

    return Column(
      children: [
        ...pagedList.map((itw) {
          final name = itw['candidate_name'] ?? 'Candidate';
          final code = itw['candidate_code'] ?? '';
          final role = itw['job_title'] ?? 'Role';
          final dept = itw['department'] ?? '';
          final round = itw['interview_round'] ?? itw['round'] ?? 'Round 1';
          final mode = itw['interview_mode'] ?? itw['mode'] ?? 'In Person';
          final isOnline = mode.toString().toLowerCase().contains('online') ||
                           mode.toString().toLowerCase().contains('video') ||
                           mode.toString().toLowerCase().contains('zoom') ||
                           mode.toString().toLowerCase().contains('meet');
          final location = (itw['location'] ?? '').toString();
          final meetingLink = (itw['meeting_link'] ?? '').toString();
          final effectiveLink = meetingLink.isNotEmpty
              ? meetingLink
              : (location.contains('http') || location.contains('.com') || location.contains('.app'))
                  ? location
                  : '';

          // Time
          String timeStr = 'Time TBD';
          if (itw['time'] != null && itw['time'].toString().isNotEmpty) {
            timeStr = itw['time'].toString();
          } else if (itw['scheduled_time_start'] != null) {
            final start = itw['scheduled_time_start'].toString().substring(0, 5);
            final end = itw['scheduled_time_end'] != null ? itw['scheduled_time_end'].toString().substring(0, 5) : '';
            timeStr = end.isNotEmpty ? '$start - $end' : start;
          }

          // Date calculation & Smart pill
          String dayNumber = '20';
          String monthStr = 'SEP';
          String weekdayStr = 'SUN';
          String tag = 'Upcoming';
          Color tagColor = const Color(0xFF0284C7);
          Color tagBg = const Color(0xFFE0F2FE);

          if (itw['scheduled_date'] != null) {
            try {
              final parsedDate = DateTime.parse(itw['scheduled_date'].toString().substring(0, 10));
              dayNumber = DateFormat('dd').format(parsedDate);
              monthStr = DateFormat('MMM').format(parsedDate).toUpperCase();
              weekdayStr = DateFormat('EEE').format(parsedDate).toUpperCase();

              final diff = parsedDate.difference(today).inDays;

              if (itw['status'] == 'Completed' || _interviewScope == 'completed') {
                tag = 'Completed';
                tagColor = const Color(0xFF16A34A);
                tagBg = const Color(0xFFDCFCE7);
              } else if (diff == 0) {
                tag = 'TODAY';
                tagColor = const Color(0xFFDC2626);
                tagBg = const Color(0xFFFEE2E2);
              } else if (diff == 1) {
                tag = 'TOMORROW';
                tagColor = const Color(0xFF4F46E5);
                tagBg = const Color(0xFFEEF2FF);
              } else if (diff > 1 && diff <= 7) {
                tag = 'In $diff days';
                tagColor = const Color(0xFF0D9488);
                tagBg = const Color(0xFFCCFBF1);
              } else if (diff < 0) {
                tag = 'Past';
                tagColor = const Color(0xFF64748B);
                tagBg = const Color(0xFFF1F5F9);
              } else {
                tag = 'In $diff days';
                tagColor = const Color(0xFF6366F1);
                tagBg = const Color(0xFFEEF2FF);
              }
            } catch (_) {}
          }

          // Panel members
          List panelList = [];
          if (itw['panel_members'] is List) {
            panelList = itw['panel_members'];
          }

          // Feedback count & rating
          final feedbackCount = (itw['feedback_count'] ?? 0) as int;
          final avgRating = itw['avg_rating'];

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  final candId = (itw['candidate_id'] ?? '').toString();
                  if (candId.isNotEmpty) {
                    _openCandidateDrawer(candId);
                  } else {
                    _openStageDetails('Interview');
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top row: Date pill + Candidate details + Smart Tag
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Calendar date badge
                          Container(
                            width: 44,
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFCBD5E1)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  monthStr,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF4F46E5),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                Text(
                                  dayNumber,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0F172A),
                                    height: 1.1,
                                  ),
                                ),
                                Text(
                                  weekdayStr,
                                  style: const TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Candidate Name, Code, Role
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1E293B),
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (code.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE2E8F0),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          code,
                                          style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  dept.isNotEmpty ? '$role • $dept' : role,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),

                          // Smart Status Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: tagBg,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: tagColor.withValues(alpha: 0.2)),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: tagColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Badges row: Round + Mode + Time
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // Round badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: const Color(0xFFC7D2FE)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.layers_outlined, size: 11, color: Color(0xFF4F46E5)),
                                const SizedBox(width: 3),
                                Text(
                                  round,
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF4338CA)),
                                ),
                              ],
                            ),
                          ),

                          // Mode badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isOnline ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(color: isOnline ? const Color(0xFFBBF7D0) : const Color(0xFFCBD5E1)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isOnline ? Icons.videocam_outlined : Icons.place_outlined,
                                  size: 11,
                                  color: isOnline ? const Color(0xFF16A34A) : const Color(0xFF475569),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  isOnline
                                      ? 'Online'
                                      : location.isNotEmpty
                                          ? 'In Person: $location'
                                          : 'In Person',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isOnline ? const Color(0xFF15803D) : const Color(0xFF334155),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Time badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.schedule_rounded, size: 11, color: Color(0xFF64748B)),
                                const SizedBox(width: 3),
                                Text(
                                  timeStr,
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF475569)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // Panel members & Feedback rating
                      if (panelList.isNotEmpty || feedbackCount > 0) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (panelList.isNotEmpty) ...[
                              const Icon(Icons.people_outline_rounded, size: 12, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Panel: ${panelList.map((p) => p['full_name'] ?? 'Interviewer').join(', ')}',
                                  style: const TextStyle(fontSize: 10, color: Color(0xFF64748B), fontStyle: FontStyle.italic),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                            if (feedbackCount > 0) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF3C7),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star_rounded, size: 11, color: Color(0xFFD97706)),
                                    const SizedBox(width: 2),
                                    Text(
                                      avgRating != null ? '$avgRating ($feedbackCount)' : '$feedbackCount rated',
                                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFFB45309)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],

                      const SizedBox(height: 8),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 6),

                      // Quick Actions Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Join Call Button (if online link available)
                          if (effectiveLink.isNotEmpty) ...[
                            ElevatedButton.icon(
                              onPressed: () => _joinMeeting(effectiveLink),
                              icon: const Icon(Icons.videocam_rounded, size: 12),
                              label: const Text('Join Call'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF16A34A),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                minimumSize: const Size(0, 26),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                                textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],

                          // Feedback Button
                          OutlinedButton.icon(
                            onPressed: () => _openInterviewFeedback(itw),
                            icon: const Icon(Icons.rate_review_outlined, size: 12),
                            label: Text(feedbackCount > 0 ? 'Feedback ($feedbackCount)' : 'Feedback'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF4F46E5),
                              side: const BorderSide(color: Color(0xFFC7D2FE)),
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                              minimumSize: const Size(0, 26),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
                              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 6),

                          // Candidate 360 / Details
                          TextButton(
                            onPressed: () {
                              final candId = (itw['candidate_id'] ?? '').toString();
                              if (candId.isNotEmpty) {
                                _openCandidateDrawer(candId);
                              }
                            },
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF475569),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              minimumSize: const Size(0, 26),
                              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                            child: const Text('Candidate 360 →'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),

        // Optimum pagination controls if more than _interviewPageSize items
        if (filteredList.length > _interviewPageSize) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing ${startIndex + 1}-$endIndex of ${filteredList.length}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, size: 18),
                    tooltip: 'Previous',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: _interviewPage > 1
                        ? () => setState(() => _interviewPage--)
                        : null,
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '$_interviewPage / $totalPages',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, size: 18),
                    tooltip: 'Next',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: _interviewPage < totalPages
                        ? () => setState(() => _interviewPage++)
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ],
      ],
    );
  }

  // ===========================================================================
  // 4. BOTTOM ROW (RECENT APPLICATIONS + RECRUITMENT ANALYTICS)
  // ===========================================================================
  Widget _buildBottomRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 960) {
          return Column(
            children: [
              _buildRecentApplicationsCard(),
              const SizedBox(height: 20),
              _buildRecruitmentAnalyticsCard(),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 50, child: _buildRecentApplicationsCard()),
            const SizedBox(width: 16),
            Expanded(flex: 50, child: _buildRecruitmentAnalyticsCard()),
          ],
        );
      },
    );
  }

  Widget _buildRecentApplicationsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [boxUnderShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recent Applications', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              InkWell(
                onTap: () => _openStageDetails('All'),
                child: const Text('View All →', style: TextStyle(fontSize: 12, color: Color(0xFF4F46E5), fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildRecentApplicationsTable(),
        ],
      ),
    );
  }

  Widget _buildRecruitmentAnalyticsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [boxUnderShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Recruitment Analytics', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              InkWell(
                onTap: _openRecruitmentAnalyticsReportDialog,
                child: const Text('View Report →', style: TextStyle(fontSize: 12, color: Color(0xFF4F46E5), fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildAnalyticsMetricsAndTrend(),
        ],
      ),
    );
  }



  Widget _buildRecentApplicationsTable() {
    if (_recentApplications.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 36, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              'No applications received yet',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    final apps = _recentApplications;

    return Column(
      children: apps.take(4).map((c) {
        final name = c['full_name'] ?? 'Candidate';
        final pos = c['applied_position'] ?? c['job_title'] ?? 'Role';
        final dateStr = c['created_at'] != null
            ? DateFormat('dd MMM yyyy').format(DateTime.parse(c['created_at'].toString().substring(0, 10)))
            : 'Recently';
        final stage = c['current_stage'] ?? 'Applied';

        Color badgeColor;
        if (stage == 'Screening') {
          badgeColor = const Color(0xFFF59E0B);
        } else if (stage == 'Interview') {
          badgeColor = const Color(0xFF0284C7);
        } else if (stage == 'Shortlisted') {
          badgeColor = const Color(0xFF8B5CF6);
        } else {
          badgeColor = const Color(0xFF64748B);
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFFE2E8F0),
                child: Text(name.isNotEmpty ? name[0] : 'C', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    Text(pos, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(stage, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: badgeColor)),
                  ),
                  const SizedBox(height: 2),
                  Text(dateStr, style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8))),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAnalyticsMetricsAndTrend() {
    final totalVacancies = _jobs.fold<int>(0, (sum, j) => sum + ((j['vacancies'] ?? 0) as num).toInt());
    final totalFilled = _jobs.fold<int>(0, (sum, j) => sum + ((j['filled_vacancies'] ?? 0) as num).toInt());
    final fillRatio = totalVacancies > 0 ? (totalFilled / totalVacancies).clamp(0.0, 1.0) : 0.0;

    final totalOffers = (_pipeline['Offer'] ?? 0) as int;
    final totalHired = (_pipeline['Hired'] ?? totalFilled) as int;
    final acceptanceRate = totalOffers > 0 ? ((totalHired / totalOffers) * 100).round() : 100;

    final monthlyCounts = List<int>.filled(12, 0);
    for (final app in _recentApplications) {
      final dateStr = app['created_at']?.toString();
      if (dateStr != null && dateStr.length >= 7) {
        try {
          final dt = DateTime.parse(dateStr.substring(0, 10));
          final mIdx = dt.month - 1;
          if (mIdx >= 0 && mIdx < 12) {
            monthlyCounts[mIdx]++;
          }
        } catch (_) {}
      }
    }
    final spots = List.generate(12, (i) => FlSpot(i.toDouble(), monthlyCounts[i].toDouble()));
    final maxAppCount = monthlyCounts.fold<int>(5, (maxVal, c) => c > maxVal ? c : maxVal);

    return Column(
      children: [
        // 3 Key Metrics Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Metric 1: Hired vs Target
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Hired vs Target', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                    const SizedBox(height: 2),
                    Text('$totalFilled / $totalVacancies', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(value: fillRatio, minHeight: 4, color: const Color(0xFF4F46E5)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Metric 2: Active Openings
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Open Positions', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                    const SizedBox(height: 2),
                    Text('${_jobs.length}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    const SizedBox(height: 4),
                    Text('${_recentApplications.length} Applicants', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Metric 3: Offer Acceptance
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Offer Acceptance', style: TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                    const SizedBox(height: 2),
                    Text('$acceptanceRate%', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                    const SizedBox(height: 4),
                    Text('$totalHired Hired', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Line Chart: Hiring Trend
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Application Trend (Monthly)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155))),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 100,
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (val, meta) {
                      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                      final idx = val.toInt();
                      if (idx >= 0 && idx < months.length) {
                        return Text(months[idx], style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8)));
                      }
                      return const Text('');
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              minX: 0,
              maxX: 11,
              minY: 0,
              maxY: (maxAppCount + 2).toDouble(),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  color: const Color(0xFF4F46E5),
                  barWidth: 2.5,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: true),
                  belowBarData: BarAreaData(
                    show: true,
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }


}

final BoxShadow boxUnderShadow = BoxShadow(
  color: const Color(0xFF0F172A).withValues(alpha: 0.04),
  blurRadius: 10,
  offset: const Offset(0, 4),
);
