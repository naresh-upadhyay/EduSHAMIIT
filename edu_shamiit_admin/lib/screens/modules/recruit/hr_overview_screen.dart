import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:edu_shamiit_core/services/api_service.dart';
import 'package:edu_shamiit_admin/widgets/hr_management_tab_header.dart';
import 'package:edu_shamiit_admin/services/hr_lookup_helper.dart';

import '../../../core/file_download_helper.dart';
import 'widgets/create_job_dialog.dart';
import 'widgets/start_onboarding_dialog.dart';
import 'widgets/create_training_dialog.dart';
import 'widgets/upload_document_dialog.dart';

class HROverviewScreen extends ConsumerStatefulWidget {
  const HROverviewScreen({super.key});

  @override
  ConsumerState<HROverviewScreen> createState() => _HROverviewScreenState();
}

class _HROverviewScreenState extends ConsumerState<HROverviewScreen> {
  final ApiService _api = ApiService();

  bool _isLoading = false;
  String? _errorMessage;
  String _alertFilter = 'ALL';

  // Real data state strictly loaded from database
  Map<String, dynamic> _data = {
    'workforce': {
      'total_employees': 0,
      'active_employees': 0,
      'on_leave_today': 0,
      'new_joiners_this_month': 0,
      'department_breakdown': <Map<String, dynamic>>[]
    },
    'recruitment': {
      'open_positions': 0,
      'total_vacancies': 0,
      'filled_vacancies': 0,
      'total_candidates': 0,
      'interviews_scheduled': 0,
      'pipeline': <Map<String, dynamic>>[],
      'upcoming_interviews': <Map<String, dynamic>>[],
      'top_openings': <Map<String, dynamic>>[],
    },
    'onboarding': {
      'active_onboardings': 0,
      'joining_this_week': 0,
      'ready_to_join': 0,
      'pending_documents': 0,
      'overdue_tasks': 0,
      'pipeline': <Map<String, dynamic>>[],
      'upcoming_joiners': <Map<String, dynamic>>[],
    },
    'training': {
      'total_programs': 0,
      'in_progress': 0,
      'completion_rate': 0.0,
      'training_hours': 0,
      'enrolled_participants': 0,
      'upcoming_sessions': 0,
      'upcoming_sessions_list': <Map<String, dynamic>>[],
      'top_programs': <Map<String, dynamic>>[],
    },
    'policies': {
      'active_policies': 0,
      'compliance_rate': 0.0,
      'expiring_documents': 0,
      'pending_acknowledgements': 0,
      'expiring_docs_list': <Map<String, dynamic>>[],
      'top_policies': <Map<String, dynamic>>[],
    },
    'pending_alerts': <Map<String, dynamic>>[],
    'recent_activities': <Map<String, dynamic>>[],
  };

  @override
  void initState() {
    super.initState();
    HRLookupHelper.instance.preloadHRLookups();
    _fetchOverviewStats();
  }

  Future<void> _fetchOverviewStats() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final res = await _api.get('/hr/overview/stats', useCache: false);
      if (res['success'] == true && res['data'] != null) {
        if (mounted) {
          setState(() {
            _data = res['data'] as Map<String, dynamic>;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = res['message']?.toString() ?? 'Unable to retrieve HR overview metrics.';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching HR overview stats: $e');
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _exportExecutiveReport() async {
    try {
      final res = await _api.getString('/hr/overview/export');
      if (mounted) {
        downloadFile(res, 'hr_executive_report_${DateTime.now().millisecondsSinceEpoch}.csv');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Executive HR Summary report downloaded (${res.length} bytes).'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export Failed: $e'),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _openQuickActionsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.bolt_rounded, color: Color(0xFF4F46E5), size: 20),
            ),
            const SizedBox(width: 12),
            const Text(
              'HR Quick Actions',
              style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildQuickActionTile(
                ctx,
                'Post New Job Opening',
                'Create a job post, set requirements and publish to careers page.',
                Icons.work_outline_rounded,
                const Color(0xFF4F46E5),
                () {
                  Navigator.of(ctx).pop();
                  showDialog(context: context, builder: (_) => CreateJobDialog(onJobCreated: _fetchOverviewStats));
                },
              ),
              const SizedBox(height: 8),
              _buildQuickActionTile(
                ctx,
                'Start New Onboarding',
                'Assign checklists, required documents and schedule employee orientation.',
                Icons.person_add_alt_1_outlined,
                const Color(0xFF0284C7),
                () {
                  Navigator.of(ctx).pop();
                  showDialog(context: context, builder: (_) => StartOnboardingDialog(onOnboardingCreated: _fetchOverviewStats));
                },
              ),
              const SizedBox(height: 8),
              _buildQuickActionTile(
                ctx,
                'Schedule Training Program',
                'Plan institutional learning, assign trainers, and track completion.',
                Icons.school_outlined,
                const Color(0xFF10B981),
                () {
                  Navigator.of(ctx).pop();
                  showDialog(context: context, builder: (_) => CreateTrainingDialog(onTrainingCreated: _fetchOverviewStats));
                },
              ),
              const SizedBox(height: 8),
              _buildQuickActionTile(
                ctx,
                'Upload Compliance Document',
                'Store institutional agreements, certificates, and compliance policies.',
                Icons.upload_file_outlined,
                const Color(0xFF8B5CF6),
                () {
                  Navigator.of(ctx).pop();
                  showDialog(context: context, builder: (_) => UploadDocumentDialog(onDocumentUploaded: _fetchOverviewStats));
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close', style: TextStyle(color: Color(0xFF64748B))),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionTile(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      hoverColor: color.withValues(alpha: 0.05),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final wf = _data['workforce'] as Map<String, dynamic>? ?? {};
    final rec = _data['recruitment'] as Map<String, dynamic>? ?? {};
    final onb = _data['onboarding'] as Map<String, dynamic>? ?? {};
    final trn = _data['training'] as Map<String, dynamic>? ?? {};
    final pol = _data['policies'] as Map<String, dynamic>? ?? {};
    final allAlerts = (_data['pending_alerts'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final activities = (_data['recent_activities'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

    final filteredAlerts = _alertFilter == 'ALL'
        ? allAlerts
        : allAlerts.where((a) => (a['module']?.toString().toLowerCase() ?? '') == _alertFilter.toLowerCase()).toList();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF090D1A) : const Color(0xFFF8FAFC),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Unified HR Management Header (Active Tab: Overview)
          HRManagementHeader(
            activeTab: HRTab.overview,
            title: 'HR Management',
            subtitle: 'Executive command center for workforce planning, talent acquisition, onboarding, training & compliance.',
            icon: Icons.dashboard_rounded,
            onRefresh: _fetchOverviewStats,
            isRefreshing: _isLoading,
            actions: [
              OutlinedButton.icon(
                onPressed: _openQuickActionsDialog,
                icon: Icon(Icons.bolt_rounded, size: 16, color: isDark ? const Color(0xFF818CF8) : const Color(0xFF4F46E5)),
                label: Text(
                  'Quick Actions',
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
                onPressed: _exportExecutiveReport,
                icon: const Icon(Icons.download_rounded, size: 16, color: Colors.white),
                label: const Text(
                  'Generate Report',
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
            ],
          ),

          if (_isLoading)
            const LinearProgressIndicator(
              minHeight: 2.5,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
            ),

          if (_errorMessage != null)
            Container(
              margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626), size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Connection notice: $_errorMessage',
                      style: const TextStyle(color: Color(0xFF991B1B), fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _fetchOverviewStats,
                    icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFFDC2626)),
                    label: const Text('Retry', style: TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),

          // Overview Dashboard Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Executive Quick Launchpad Bar (Direct access to all 4 pillars)
                  _buildPillarQuickLaunchpad(isDark),
                  const SizedBox(height: 20),

                  // 2. Top 6 Metric Cards Row
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 1100;
                      if (isNarrow) {
                        return Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            _buildStatCard(
                              title: 'Total Workforce',
                              value: '${wf['total_employees'] ?? 0}',
                              sub: '${wf['active_employees'] ?? 0} Active • ${wf['on_leave_today'] ?? 0} on leave',
                              icon: Icons.groups_outlined,
                              color: const Color(0xFF4F46E5),
                              isDark: isDark,
                              width: (constraints.maxWidth - 16) / 2,
                              onTap: () => context.go('/admin/staff'),
                            ),
                            _buildStatCard(
                              title: 'Open Positions',
                              value: '${rec['open_positions'] ?? 0}',
                              sub: '${rec['total_vacancies'] ?? rec['open_positions'] ?? 0} Vacancies active',
                              icon: Icons.work_outline_rounded,
                              color: const Color(0xFF0284C7),
                              isDark: isDark,
                              width: (constraints.maxWidth - 16) / 2,
                              onTap: () => context.go('/admin/hr/recruitment'),
                            ),
                            _buildStatCard(
                              title: 'Candidates in Pipeline',
                              value: '${rec['total_candidates'] ?? 0}',
                              sub: '${rec['interviews_scheduled'] ?? 0} interviews this week',
                              icon: Icons.badge_outlined,
                              color: const Color(0xFFF59E0B),
                              isDark: isDark,
                              width: (constraints.maxWidth - 16) / 2,
                              onTap: () => context.go('/admin/hr/recruitment'),
                            ),
                            _buildStatCard(
                              title: 'Active Onboarding',
                              value: '${onb['active_onboardings'] ?? 0}',
                              sub: '${onb['joining_this_week'] ?? 0} joining this week',
                              icon: Icons.person_add_alt_1_outlined,
                              color: const Color(0xFF10B981),
                              isDark: isDark,
                              width: (constraints.maxWidth - 16) / 2,
                              onTap: () => context.go('/admin/hr/onboarding'),
                            ),
                            _buildStatCard(
                              title: 'Training In Progress',
                              value: '${trn['in_progress'] ?? 0}',
                              sub: '${trn['completion_rate'] ?? 0}% avg completion',
                              icon: Icons.school_outlined,
                              color: const Color(0xFF8B5CF6),
                              isDark: isDark,
                              width: (constraints.maxWidth - 16) / 2,
                              onTap: () => context.go('/admin/hr/training'),
                            ),
                            _buildStatCard(
                              title: 'Policies & Compliance',
                              value: '${pol['compliance_rate'] ?? 0}%',
                              sub: '${pol['expiring_documents'] ?? 0} docs expiring soon',
                              icon: Icons.lock_outline_rounded,
                              color: const Color(0xFFEC4899),
                              isDark: isDark,
                              width: (constraints.maxWidth - 16) / 2,
                              onTap: () => context.go('/admin/hr/policies'),
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              title: 'Total Workforce',
                              value: '${wf['total_employees'] ?? 0}',
                              sub: '${wf['active_employees'] ?? 0} Active • ${wf['on_leave_today'] ?? 0} on leave',
                              icon: Icons.groups_outlined,
                              color: const Color(0xFF4F46E5),
                              isDark: isDark,
                              onTap: () => context.go('/admin/staff'),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildStatCard(
                              title: 'Open Positions',
                              value: '${rec['open_positions'] ?? 0}',
                              sub: '${rec['total_vacancies'] ?? rec['open_positions'] ?? 0} Vacancies active',
                              icon: Icons.work_outline_rounded,
                              color: const Color(0xFF0284C7),
                              isDark: isDark,
                              onTap: () => context.go('/admin/hr/recruitment'),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildStatCard(
                              title: 'Pipeline Candidates',
                              value: '${rec['total_candidates'] ?? 0}',
                              sub: '${rec['interviews_scheduled'] ?? 0} interviews scheduled',
                              icon: Icons.badge_outlined,
                              color: const Color(0xFFF59E0B),
                              isDark: isDark,
                              onTap: () => context.go('/admin/hr/recruitment'),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildStatCard(
                              title: 'Active Onboarding',
                              value: '${onb['active_onboardings'] ?? 0}',
                              sub: '${onb['joining_this_week'] ?? 0} joining this week',
                              icon: Icons.person_add_alt_1_outlined,
                              color: const Color(0xFF10B981),
                              isDark: isDark,
                              onTap: () => context.go('/admin/hr/onboarding'),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildStatCard(
                              title: 'Training In Progress',
                              value: '${trn['in_progress'] ?? 0}',
                              sub: '${trn['completion_rate'] ?? 0}% completion rate',
                              icon: Icons.school_outlined,
                              color: const Color(0xFF8B5CF6),
                              isDark: isDark,
                              onTap: () => context.go('/admin/hr/training'),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _buildStatCard(
                              title: 'Compliance Rate',
                              value: '${pol['compliance_rate'] ?? 0}%',
                              sub: '${pol['expiring_documents'] ?? 0} docs expiring',
                              icon: Icons.lock_outline_rounded,
                              color: const Color(0xFFEC4899),
                              isDark: isDark,
                              onTap: () => context.go('/admin/hr/policies'),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // 3. PILLARS 1 & 2 COMMAND ROW: Recruitment & Onboarding Deep Overviews
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pillar 1: Talent Acquisition & Recruitment Hub
                      Expanded(
                        flex: 6,
                        child: _buildRecruitmentCommandHub(rec, isDark),
                      ),
                      const SizedBox(width: 20),

                      // Pillar 2: Employee Onboarding Progression & Task Matrix Hub
                      Expanded(
                        flex: 6,
                        child: _buildOnboardingCommandHub(onb, isDark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 4. PILLARS 3 & 4 COMMAND ROW: Training & Policies Deep Overviews
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pillar 3: Professional Learning & Training Hub
                      Expanded(
                        flex: 6,
                        child: _buildTrainingCommandHub(trn, isDark),
                      ),
                      const SizedBox(width: 20),

                      // Pillar 4: Institutional Policies & Compliance Hub
                      Expanded(
                        flex: 6,
                        child: _buildPoliciesCommandHub(pol, isDark),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // 5. Bottom Section: Actionable Pending Alerts & Recent Activities
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Pending Alerts with Pillar Filter Chips
                      Expanded(
                        flex: 7,
                        child: _buildPendingAlertsSection(filteredAlerts, allAlerts.length, isDark),
                      ),
                      const SizedBox(width: 20),

                      // Recent Cross-Module Activity
                      Expanded(
                        flex: 5,
                        child: _buildRecentActivitiesSection(activities, isDark),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // EXECUTIVE QUICK LAUNCHPAD
  // --------------------------------------------------------------------------
  Widget _buildPillarQuickLaunchpad(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13182C) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.hub_outlined, color: Color(0xFF4F46E5), size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'Sub-Module Quick Jump:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Outfit'),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                _buildQuickJumpChip('1. Recruitment Hub', Icons.badge_outlined, const Color(0xFF0284C7), '/admin/hr/recruitment', isDark),
                _buildQuickJumpChip('2. Onboarding Suite', Icons.person_add_alt_1_outlined, const Color(0xFF10B981), '/admin/hr/onboarding', isDark),
                _buildQuickJumpChip('3. Training & Learning', Icons.school_outlined, const Color(0xFF8B5CF6), '/admin/hr/training', isDark),
                _buildQuickJumpChip('4. Policies & Vault', Icons.lock_outline_rounded, const Color(0xFFEC4899), '/admin/hr/policies', isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickJumpChip(String label, IconData icon, Color color, String route, bool isDark) {
    return InkWell(
      onTap: () => context.go(route),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color, fontFamily: 'Inter'),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_forward_rounded, size: 12, color: color),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // TOP STAT CARD
  // --------------------------------------------------------------------------
  Widget _buildStatCard({
    required String title,
    required String value,
    required String sub,
    required IconData icon,
    required Color color,
    required bool isDark,
    double? width,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: width,
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
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      fontFamily: 'Inter',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              sub,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                overflow: TextOverflow.ellipsis,
              ),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // PILLAR 1: RECRUITMENT COMMAND HUB
  // --------------------------------------------------------------------------
  Widget _buildRecruitmentCommandHub(Map<String, dynamic> rec, bool isDark) {
    final pipeline = (rec['pipeline'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final upcomingItws = (rec['upcoming_interviews'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final topOpenings = (rec['top_openings'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.badge_outlined, color: Color(0xFF0284C7), size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recruitment & Talent Acquisition',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                      ),
                      Text(
                        'Funnel stages, scheduled interviews & active job openings',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => context.go('/admin/hr/recruitment'),
                icon: const Icon(Icons.open_in_new_rounded, size: 14, color: Color(0xFF0284C7)),
                label: const Text('Open Hub', style: TextStyle(fontSize: 12, color: Color(0xFF0284C7), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Pipeline Funnel Bar
          Row(
            children: pipeline.map((item) {
              final stage = item['stage'] as String? ?? '';
              final count = item['count'] as int? ?? 0;
              final colorHex = (item['color'] as String? ?? '#0284C7').replaceAll('#', '0xFF');
              final color = Color(int.tryParse(colorHex) ?? 0xFF0284C7);

              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: color.withValues(alpha: 0.2)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$count',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color, fontFamily: 'Outfit'),
                      ),
                      Text(
                        stage,
                        style: TextStyle(fontSize: 10, color: isDark ? Colors.white70 : const Color(0xFF475569), fontWeight: FontWeight.w500),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Sub-screen 1: Next Scheduled Interviews Spotlight
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0B1020) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.event_available_outlined, size: 15, color: Color(0xFF0284C7)),
                        SizedBox(width: 6),
                        Text(
                          'Upcoming Scheduled Interviews',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                        ),
                      ],
                    ),
                    Text(
                      '${rec['interviews_scheduled'] ?? 0} scheduled',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF0284C7), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (upcomingItws.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      'No interviews scheduled for the next 7 days.',
                      style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  )
                else
                  Column(
                    children: upcomingItws.take(2).map((itw) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                itw['scheduled_date']?.toString().split(' ').first ?? 'Date',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${itw['candidate_name']} • ${itw['job_title']}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              itw['round_name'] ?? 'Interview',
                              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Sub-screen 2: Active Openings Quick List
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Active Openings: ${rec['open_positions'] ?? 0} jobs (${rec['total_vacancies'] ?? 0} vacancies)',
                style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
              InkWell(
                onTap: () => context.go('/admin/hr/recruitment'),
                child: const Text('Manage Openings →', style: TextStyle(fontSize: 11, color: Color(0xFF0284C7), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          if (topOpenings.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: topOpenings.take(3).map((job) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${job['job_title']} (${job['vacancies']} pos)',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // PILLAR 2: ONBOARDING COMMAND HUB
  // --------------------------------------------------------------------------
  Widget _buildOnboardingCommandHub(Map<String, dynamic> onb, bool isDark) {
    final pipeline = (onb['pipeline'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final upcomingJoiners = (onb['upcoming_joiners'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

    final maxCount = pipeline.fold<int>(1, (max, item) {
      final c = (item['count'] as num?)?.toInt() ?? 0;
      return c > max ? c : max;
    });

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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.person_add_alt_1_outlined, color: Color(0xFF10B981), size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Employee Onboarding Pipeline',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                      ),
                      Text(
                        'New hire progression, document verification & task matrix',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => context.go('/admin/hr/onboarding'),
                icon: const Icon(Icons.open_in_new_rounded, size: 14, color: Color(0xFF10B981)),
                label: const Text('Open Hub', style: TextStyle(fontSize: 12, color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 6-Stage Progress Bars (Compact)
          Column(
            children: pipeline.take(4).map((item) {
              final stage = item['stage'] as String? ?? '';
              final count = item['count'] as int? ?? 0;
              final pct = count > 0 ? (count / maxCount).clamp(0.05, 1.0) : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 130,
                      child: Text(
                        stage,
                        style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569), fontWeight: FontWeight.w500),
                      ),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 6,
                          backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 24,
                      child: Text(
                        '$count',
                        textAlign: TextAlign.end,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),

          // Sub-screen 1: New Joiners Spotlight
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0B1020) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.how_to_reg_outlined, size: 15, color: Color(0xFF10B981)),
                        SizedBox(width: 6),
                        Text(
                          'Upcoming New Joiners',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                        ),
                      ],
                    ),
                    Text(
                      '${onb['joining_this_week'] ?? 0} joining this week',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (upcomingJoiners.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      'No new joiners scheduled this week.',
                      style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  )
                else
                  Column(
                    children: upcomingJoiners.take(2).map((jnr) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                jnr['joining_date']?.toString().split(' ').first ?? 'Date',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${jnr['candidate_name']} • ${jnr['designation']}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                jnr['stage'] ?? 'Stage',
                                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Sub-screen 2: Action Bottlenecks (Docs & Tasks)
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.file_copy_outlined, size: 16, color: Color(0xFFEF4444)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${onb['pending_documents'] ?? 0} Docs Pending',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFEF4444)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.assignment_late_outlined, size: 16, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${onb['overdue_tasks'] ?? 0} Tasks Overdue',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // PILLAR 3: TRAINING COMMAND HUB
  // --------------------------------------------------------------------------
  Widget _buildTrainingCommandHub(Map<String, dynamic> trn, bool isDark) {
    final upcomingSessions = (trn['upcoming_sessions_list'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final topPrograms = (trn['top_programs'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.school_outlined, color: Color(0xFF8B5CF6), size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Training & Professional Learning',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                      ),
                      Text(
                        'Course catalog, active workshops & faculty completion rates',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => context.go('/admin/hr/training'),
                icon: const Icon(Icons.open_in_new_rounded, size: 14, color: Color(0xFF8B5CF6)),
                label: const Text('Open Hub', style: TextStyle(fontSize: 12, color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 4 Mini KPIs
          Row(
            children: [
              _buildMiniMetric('Total Programs', '${trn['total_programs'] ?? 0}', const Color(0xFF8B5CF6), isDark),
              const SizedBox(width: 8),
              _buildMiniMetric('In Progress', '${trn['in_progress'] ?? 0}', const Color(0xFF0284C7), isDark),
              const SizedBox(width: 8),
              _buildMiniMetric('Avg Completion', '${trn['completion_rate'] ?? 0}%', const Color(0xFF10B981), isDark),
              const SizedBox(width: 8),
              _buildMiniMetric('Training Hours', '${trn['training_hours'] ?? 0}h', const Color(0xFFF59E0B), isDark),
            ],
          ),
          const SizedBox(height: 16),

          // Sub-screen 1: Upcoming Training Sessions Agenda
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0B1020) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.calendar_month_outlined, size: 15, color: Color(0xFF8B5CF6)),
                        SizedBox(width: 6),
                        Text(
                          'Upcoming Training Sessions',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                        ),
                      ],
                    ),
                    Text(
                      '${trn['upcoming_sessions'] ?? 0} scheduled',
                      style: const TextStyle(fontSize: 11, color: Color(0xFF8B5CF6), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (upcomingSessions.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      'No upcoming workshops scheduled this week.',
                      style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  )
                else
                  Column(
                    children: upcomingSessions.take(2).map((sess) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                sess['session_date']?.toString().split(' ').first ?? 'Date',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${sess['session_title']} (${sess['trainer_name']})',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${sess['enrolled_count']} enrolled',
                              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Sub-screen 2: Active Training Programs
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Active Programs Catalog (${trn['in_progress'] ?? 0} active)',
                style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
              InkWell(
                onTap: () => context.go('/admin/hr/training'),
                child: const Text('View All Programs →', style: TextStyle(fontSize: 11, color: Color(0xFF8B5CF6), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          if (topPrograms.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: topPrograms.take(3).map((prog) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${prog['title']} • ${prog['completion_rate']}%',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  // --------------------------------------------------------------------------
  // PILLAR 4: POLICIES COMMAND HUB
  // --------------------------------------------------------------------------
  Widget _buildPoliciesCommandHub(Map<String, dynamic> pol, bool isDark) {
    final expDocs = (pol['expiring_docs_list'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    final topPols = (pol['top_policies'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEC4899).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.verified_outlined, color: Color(0xFFEC4899), size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Policies & Compliance Vault',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                      ),
                      Text(
                        'Compliance rates, document expiries & digital sign-offs',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => context.go('/admin/hr/policies'),
                icon: const Icon(Icons.open_in_new_rounded, size: 14, color: Color(0xFFEC4899)),
                label: const Text('Open Hub', style: TextStyle(fontSize: 12, color: Color(0xFFEC4899), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 4 Mini KPIs
          Row(
            children: [
              _buildMiniMetric('Active Policies', '${pol['active_policies'] ?? 0}', const Color(0xFFEC4899), isDark),
              const SizedBox(width: 8),
              _buildMiniMetric('Compliance', '${pol['compliance_rate'] ?? 0}%', const Color(0xFF10B981), isDark),
              const SizedBox(width: 8),
              _buildMiniMetric('Expiring Docs', '${pol['expiring_documents'] ?? 0}', const Color(0xFFEF4444), isDark),
              const SizedBox(width: 8),
              _buildMiniMetric('Sign-offs Due', '${pol['pending_acknowledgements'] ?? 0}', const Color(0xFFF59E0B), isDark),
            ],
          ),
          const SizedBox(height: 16),

          // Sub-screen 1: Expiring Compliance Documents Watchlist
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0B1020) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.event_busy_outlined, size: 15, color: Color(0xFFEF4444)),
                        SizedBox(width: 6),
                        Text(
                          'Expiring Compliance Documents',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                        ),
                      ],
                    ),
                    Text(
                      '${pol['expiring_documents'] ?? 0} expiring soon',
                      style: const TextStyle(fontSize: 11, color: Color(0xFFEF4444), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (expDocs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      'All institutional and staff documents are currently up-to-date.',
                      style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  )
                else
                  Column(
                    children: expDocs.take(2).map((doc) {
                      final daysLeft = doc['days_left'] as int? ?? 30;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: (daysLeft < 15 ? const Color(0xFFEF4444) : const Color(0xFFF59E0B)).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$daysLeft d left',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: daysLeft < 15 ? const Color(0xFFEF4444) : const Color(0xFFF59E0B),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${doc['title']} • ${doc['document_type']}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              doc['expiry_date']?.toString().split(' ').first ?? '',
                              style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Sub-screen 2: Active Policies List
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Active Policies (${pol['active_policies'] ?? 0} published)',
                style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
              InkWell(
                onTap: () => context.go('/admin/hr/policies'),
                child: const Text('Manage Policies →', style: TextStyle(fontSize: 11, color: Color(0xFFEC4899), fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          if (topPols.isNotEmpty) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: topPols.take(3).map((po) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${po['title']} (${po['version']})',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniMetric(String label, String value, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.15)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color, fontFamily: 'Outfit'),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: isDark ? Colors.white70 : const Color(0xFF475569)),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // ACTIONABLE PENDING ALERTS SECTION
  // --------------------------------------------------------------------------
  Widget _buildPendingAlertsSection(List<Map<String, dynamic>> alerts, int totalAlerts, bool isDark) {
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.notifications_active_outlined, color: Color(0xFFEF4444), size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Actionable Pending HR Alerts',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$totalAlerts require action',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFEF4444)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Filter Chips by Pillar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildAlertFilterChip('All Pillars', 'ALL', isDark),
                const SizedBox(width: 8),
                _buildAlertFilterChip('Onboarding', 'onboarding', isDark),
                const SizedBox(width: 8),
                _buildAlertFilterChip('Compliance', 'policies', isDark),
                const SizedBox(width: 8),
                _buildAlertFilterChip('Training', 'training', isDark),
                const SizedBox(width: 8),
                _buildAlertFilterChip('Recruitment', 'recruitment', isDark),
              ],
            ),
          ),
          const SizedBox(height: 14),

          if (alerts.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.check_circle_outline_rounded, size: 36, color: const Color(0xFF10B981).withValues(alpha: 0.7)),
                    const SizedBox(height: 8),
                    Text(
                      'No pending alerts for this category',
                      style: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            )
          else
            Column(
              children: alerts.map((item) {
                final title = item['title'] as String? ?? '';
                final desc = item['description'] as String? ?? '';
                final badge = item['badge'] as String? ?? 'Action';
                final severity = item['severity'] as String? ?? 'INFO';
                final route = item['target_route'] as String? ?? '/admin/hr/recruitment';

                Color badgeColor;
                if (severity == 'CRITICAL') {
                  badgeColor = const Color(0xFFEF4444);
                } else if (severity == 'HIGH') {
                  badgeColor = const Color(0xFFF59E0B);
                } else if (severity == 'MEDIUM') {
                  badgeColor = const Color(0xFF8B5CF6);
                } else {
                  badgeColor = const Color(0xFF0284C7);
                }

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0B1020) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: badgeColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    title,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: badgeColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    badge,
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              desc,
                              style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton(
                        onPressed: () => context.go(route),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          foregroundColor: const Color(0xFF4F46E5),
                          elevation: 0,
                          side: const BorderSide(color: Color(0xFFCBD5E1)),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('Resolve', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward_rounded, size: 12),
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

  Widget _buildAlertFilterChip(String label, String value, bool isDark) {
    final isSelected = _alertFilter == value;
    return InkWell(
      onTap: () => setState(() => _alertFilter = value),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF4F46E5)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  // RECENT ACTIVITIES SECTION
  // --------------------------------------------------------------------------
  Widget _buildRecentActivitiesSection(List<Map<String, dynamic>> activities, bool isDark) {
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.history_rounded, color: Color(0xFF4F46E5), size: 18),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Recent HR Activities',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                  ),
                ],
              ),
              const Icon(Icons.timeline_rounded, size: 18, color: Color(0xFF94A3B8)),
            ],
          ),
          const SizedBox(height: 16),
          if (activities.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No recent activity records found.',
                  style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                ),
              ),
            )
          else
            Column(
              children: activities.map((item) {
                final module = item['module'] as String? ?? 'HR';
                final action = item['action'] as String? ?? 'Action';
                final desc = item['description'] as String? ?? '';
                final actor = item['actor_name'] as String? ?? 'HR Admin';

                Color modColor;
                if (module == 'recruitment') {
                  modColor = const Color(0xFF0284C7);
                } else if (module == 'onboarding') {
                  modColor = const Color(0xFF10B981);
                } else if (module == 'training') {
                  modColor = const Color(0xFF8B5CF6);
                } else {
                  modColor = const Color(0xFFEC4899);
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 2),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: modColor.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.circle, size: 8, color: modColor),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  action,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: modColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    module.toUpperCase(),
                                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: modColor),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              desc,
                              style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'By $actor',
                              style: TextStyle(fontSize: 10, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                            ),
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
}

extension DateTimeFormatExtension on DateTime {
  String toIsoformatString() => toIso8601String();
}
