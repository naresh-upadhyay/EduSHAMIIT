import 'package:flutter/material.dart';
import 'package:edu_shamiit_core/services/api_service.dart';

class OnboardingGuideDialog extends StatefulWidget {
  final int initialTabIndex;
  final VoidCallback? onAddNewHire;
  final VoidCallback? onOpenPipeline;

  const OnboardingGuideDialog({
    super.key,
    this.initialTabIndex = 0,
    this.onAddNewHire,
    this.onOpenPipeline,
  });

  @override
  State<OnboardingGuideDialog> createState() => _OnboardingGuideDialogState();
}

class _OnboardingGuideDialogState extends State<OnboardingGuideDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _api = ApiService();

  bool _isLoadingTemplates = true;
  List<dynamic> _templates = [];

  // Expanded template tracker
  final Set<String> _expandedTemplates = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this, initialIndex: widget.initialTabIndex);
    _fetchTemplates();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchTemplates() async {
    setState(() => _isLoadingTemplates = true);
    try {
      final res = await _api.get('/onboarding/templates', useCache: false);
      if (res['success'] == true && res['data'] is List) {
        setState(() {
          _templates = res['data'] as List;
          _isLoadingTemplates = false;
        });
      } else {
        setState(() => _isLoadingTemplates = false);
      }
    } catch (_) {
      setState(() => _isLoadingTemplates = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 880,
        height: 720,
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.95,
          maxHeight: MediaQuery.of(context).size.height * 0.92,
        ),
        child: Column(
          children: [
            // 1. Dialog Header
            _buildDialogHeader(isDark),

            // 2. Tab Navigation
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF13182C) : const Color(0xFFF8FAFC),
                border: Border(
                  bottom: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: EdgeInsets.zero,
                labelColor: const Color(0xFF4F46E5),
                unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                indicatorColor: const Color(0xFF4F46E5),
                indicatorWeight: 3,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                tabs: const [
                  Tab(icon: Icon(Icons.route_outlined, size: 18), text: 'Workflow & 6 Stages'),
                  Tab(icon: Icon(Icons.assignment_outlined, size: 18), text: 'Department Checklists'),
                  Tab(icon: Icon(Icons.forward_to_inbox_rounded, size: 18), text: 'Automated Triggers'),
                  Tab(icon: Icon(Icons.help_outline_rounded, size: 18), text: 'HR Best Practices & FAQs'),
                ],
              ),
            ),

            // 3. Tab Views Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildWorkflowTab(isDark),
                  _buildDepartmentTemplatesTab(isDark),
                  _buildAutomatedTriggersTab(isDark),
                  _buildFaqTab(isDark),
                ],
              ),
            ),

            // 4. Footer Actions
            _buildDialogFooter(isDark),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // HEADER
  // ==========================================================================
  Widget _buildDialogHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13182C) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        border: Border(
          bottom: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4F46E5), Color(0xFF6366F1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Onboarding Operations Guide & Policies',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit',
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Standard Operating Procedure',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Complete enterprise manual: 6-stage lifecycle progression, automated communications, compliance checklists, and department templates.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // TAB 1: WORKFLOW & 6 STAGES
  // ==========================================================================
  Widget _buildWorkflowTab(bool isDark) {
    final stages = [
      {
        'stage': 'Offer Accepted',
        'badge': 'Stage 1',
        'color': const Color(0xFF6366F1),
        'icon': Icons.handshake_outlined,
        'summary': 'Candidate formally accepts the offer letter. Onboarding file is generated and welcome pack is prepared.',
        'sla': 'Day 0 to Day 2',
        'key_actions': [
          'Generate unique Employee ID (e.g., EMP1386) and assign onboarding code.',
          'Assign designated HR Operations Owner and Reporting Manager.',
          'Dispatch automated Welcome Email with preliminary reporting venue and documentation guidelines.',
          'Activate candidate profile in the Onboarding Pipeline workspace.',
        ],
        'exit_criteria': 'Candidate profile active in system, HR owner assigned, and welcome notification confirmed.',
      },
      {
        'stage': 'Document Collection',
        'badge': 'Stage 2',
        'color': const Color(0xFF0EA5E9),
        'icon': Icons.description_outlined,
        'summary': 'Candidate submits mandatory statutory, academic, and identification documents for compliance auditing.',
        'sla': 'Day 3 to Day 7',
        'key_actions': [
          'Candidate uploads Aadhaar/National ID, Degree Certificates, Relieving Letter, and Bank Details.',
          'HR team reviews scanned uploads against original credentials with Approve / Reject remarks.',
          'Send automated email reminders for missing or rejected documents with specific guidance.',
          'Conduct statutory background checks (police verification, academic credential validation).',
        ],
        'exit_criteria': '100% of mandatory department documents verified by authorized HR personnel.',
      },
      {
        'stage': 'Orientation',
        'badge': 'Stage 3',
        'color': const Color(0xFF10B981),
        'icon': Icons.how_to_reg_outlined,
        'summary': 'First day campus reception, institutional culture induction, and staff handbook sign-off.',
        'sla': 'Day 1 of Joining',
        'key_actions': [
          'Welcome meeting with Principal, Director, and Department Head.',
          'Guided campus tour: classrooms, laboratories, library, and staff lounge.',
          'Walkthrough of Institutional Code of Conduct, child protection policies, and leave rules.',
          'Issue Physical Staff ID Card and emergency contact registration.',
        ],
        'exit_criteria': 'Orientation attendance logged, policy handbook acknowledgement signed.',
      },
      {
        'stage': 'IT Setup',
        'badge': 'Stage 4',
        'color': const Color(0xFFF59E0B),
        'icon': Icons.computer_outlined,
        'summary': 'Digital workspace allocation: institutional email, biometric registration, and hardware handover.',
        'sla': 'Day 1 to Day 2',
        'key_actions': [
          'Provision official institutional email address (@edushamiit.com).',
          'Configure ERP system login, role-based access controls (RBAC), and LMS accounts.',
          'Register fingerprint/facial biometric profile for daily attendance tracking.',
          'Allocate laptop/workstation and sign digital asset handover agreement.',
        ],
        'exit_criteria': 'System access verified, test login successful, asset agreement filed.',
      },
      {
        'stage': 'Training',
        'badge': 'Stage 5',
        'color': const Color(0xFFEC4899),
        'icon': Icons.school_outlined,
        'summary': 'Role readiness: curriculum planning, grading module training, and peer mentorship.',
        'sla': 'Week 1 to Week 2',
        'key_actions': [
          'Academic curriculum review, syllabus distribution, and lesson plan templates.',
          'ERP Student Grading & Attendance module operational training.',
          'Assign Senior Department Mentor for 30-day peer shadowing and guidance.',
          'Classroom tech setup: smart board operation, audio-visual controls, and lab safety rules.',
        ],
        'exit_criteria': 'Department Head training sign-off, mentorship agreement activated.',
      },
      {
        'stage': 'Completed',
        'badge': 'Stage 6',
        'color': const Color(0xFF8B5CF6),
        'icon': Icons.verified_outlined,
        'summary': 'Final integration: probation tracking activated, staff directory synchronization, and official confirmation.',
        'sla': 'By Day 14',
        'key_actions': [
          'Final audit: verify all tasks and documents are resolved or covered by authorized override.',
          'Sync new hire record to Active Staff Directory and Payroll master.',
          'Initialize probation review timeline (3-month & 6-month evaluation milestones).',
          'Dispatch official "Welcome to the Team" confirmation email to candidate.',
        ],
        'exit_criteria': 'Onboarding status marked "Completed", payroll activated, 100% formal sign-off.',
      },
    ];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // Workflow Summary Banner
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: Color(0xFF4F46E5), size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Every new hire advances through 6 sequential stages. Stages can be transitioned individually from the New Joiners table, 360 Detail Drawer, or by drag-and-drop in the Pipeline Workspace.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? const Color(0xFFC7D2FE) : const Color(0xFF3730A3),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        ...stages.map((s) {
          final color = s['color'] as Color;
          final icon = s['icon'] as IconData;
          final actions = s['key_actions'] as List<String>;

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
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
                // Stage Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      topRight: Radius.circular(12),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: color, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          s['badge'] as String,
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        s['stage'] as String,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.timer_outlined, size: 13, color: color),
                            const SizedBox(width: 4),
                            Text(
                              'Target: ${s['sla']}',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white : const Color(0xFF334155)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Stage Body
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s['summary'] as String,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 14),

                      const Text(
                        'Key Operations & Protocols:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                      ),
                      const SizedBox(height: 8),

                      ...actions.map((act) => Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('  •  ', style: TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold)),
                                Expanded(
                                  child: Text(
                                    act,
                                    style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                  ),
                                ),
                              ],
                            ),
                          )),

                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF10B981)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Exit Milestone: ${s['exit_criteria']}',
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF10B981)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ==========================================================================
  // TAB 2: DEPARTMENT TEMPLATES & CHECKLISTS
  // ==========================================================================
  Widget _buildDepartmentTemplatesTab(bool isDark) {
    if (_isLoadingTemplates) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_templates.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.assignment_outlined, size: 48, color: Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            const Text('No custom department templates found.', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Standard school onboarding policies are active.', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0EA5E9).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF0EA5E9).withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.rule_folder_outlined, color: Color(0xFF0EA5E9), size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'When a new hire is added with a department selection, the corresponding checklist tasks and mandatory document requirements are automatically bound to their profile.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? const Color(0xFFBAE6FD) : const Color(0xFF0369A1),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        ..._templates.map((tmpl) {
          final id = tmpl['id']?.toString() ?? tmpl['name'] ?? '';
          final name = tmpl['name'] ?? 'Department Policy';
          final dept = tmpl['department'] ?? 'General';
          final desc = tmpl['description'] ?? 'Automated onboarding checklist and mandatory documents.';
          final docs = (tmpl['default_documents'] as List?) ?? [];
          final tasks = (tmpl['default_tasks'] as List?) ?? [];

          final isExpanded = _expandedTemplates.contains(id);

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF13182C) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isExpanded
                    ? const Color(0xFF4F46E5)
                    : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                width: isExpanded ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Bar
                InkWell(
                  onTap: () {
                    setState(() {
                      if (isExpanded) {
                        _expandedTemplates.remove(id);
                      } else {
                        _expandedTemplates.add(id);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.badge_outlined, color: Color(0xFF4F46E5), size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text('Active Policy', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Department: $dept  •  ${tasks.length} Checklist Tasks  •  ${docs.length} Required Documents',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ],
                    ),
                  ),
                ),

                // Expanded Breakdown
                if (isExpanded) ...[
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          desc,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Two Column: Tasks & Documents
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Checklist Tasks Column
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.check_box_outlined, size: 16, color: Color(0xFF4F46E5)),
                                        const SizedBox(width: 6),
                                        Text('Checklist Tasks (${tasks.length})',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    if (tasks.isEmpty)
                                      const Text('No pre-configured tasks.', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))
                                    else
                                      ...tasks.map((t) {
                                        final title = t is Map ? (t['title'] ?? 'Task') : t.toString();
                                        final team = t is Map ? (t['assigned_team'] ?? 'HR') : 'HR';
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 6),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF10B981)),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text('$title ($team)', style: const TextStyle(fontSize: 11.5)),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Required Documents Column
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.folder_open_outlined, size: 16, color: Color(0xFF0EA5E9)),
                                        const SizedBox(width: 6),
                                        Text('Mandatory Documents (${docs.length})',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    if (docs.isEmpty)
                                      const Text('No mandatory documents specified.', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)))
                                    else
                                      ...docs.map((d) {
                                        final dName = d is Map ? (d['document_name'] ?? 'Doc') : d.toString();
                                        return Padding(
                                          padding: const EdgeInsets.only(bottom: 6),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Icon(Icons.description_outlined, size: 14, color: Color(0xFF0EA5E9)),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(dName, style: const TextStyle(fontSize: 11.5)),
                                              ),
                                            ],
                                          ),
                                        );
                                      }),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  // ==========================================================================
  // TAB 3: AUTOMATED TRIGGERS & COMMUNICATIONS
  // ==========================================================================
  Widget _buildAutomatedTriggersTab(bool isDark) {
    final triggers = [
      {
        'event': 'Onboarding Created / Initiated',
        'type': 'Automated Welcome Dispatch',
        'icon': Icons.mail_outline_rounded,
        'color': const Color(0xFF4F46E5),
        'desc': 'Dispatched immediately when a candidate is added to onboarding. Contains their official Employee ID, reporting date & venue, assigned HR contact, and portal login instructions.',
        'recipient': 'New Hire Email',
      },
      {
        'event': 'Send Onboarding Reminder',
        'type': 'Action Checklist Reminder',
        'icon': Icons.notifications_active_outlined,
        'color': const Color(0xFFF59E0B),
        'desc': 'Triggered on demand from the New Joiners table or 360 Detail Drawer. Lists all outstanding mandatory documents, overdue tasks, and includes an optional custom note from HR.',
        'recipient': 'New Hire Email',
      },
      {
        'event': 'Pipeline Stage Advancement',
        'type': 'Stage Progression Notification',
        'icon': Icons.published_with_changes_rounded,
        'color': const Color(0xFF0EA5E9),
        'desc': 'Sent automatically when a candidate is moved to a new stage (e.g., from Document Collection to Orientation). Informs candidate of their progress and next immediate steps.',
        'recipient': 'New Hire & Reporting Manager',
      },
      {
        'event': 'Joining Date Rescheduled',
        'type': 'Formal Date Amendment',
        'icon': Icons.calendar_month_outlined,
        'color': const Color(0xFFEC4899),
        'desc': 'Triggered when the expected joining date is revised in the 360 Detail Drawer. Updates the candidate with the new reporting date and logs audit justification.',
        'recipient': 'New Hire, Department Head & IT Team',
      },
      {
        'event': 'Onboarding Completed',
        'type': 'Welcome to Team & Payroll Sync',
        'icon': Icons.verified_outlined,
        'color': const Color(0xFF10B981),
        'desc': 'Final dispatch confirming successful onboarding completion. Activates candidate in staff directory and synchronizes profile with payroll.',
        'recipient': 'New Hire, Principal, HR Director',
      },
    ];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.send_rounded, color: Color(0xFF10B981), size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'All email dispatches are sent via encrypted Google SMTP (smtp.gmail.com:587) with HTML responsive layouts, institutional branding, and full audit trail logging.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF065F46),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        ...triggers.map((trig) {
          final color = trig['color'] as Color;
          final icon = trig['icon'] as IconData;

          return Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF13182C) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            trig['event'] as String,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              trig['type'] as String,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        trig['desc'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.alternate_email_rounded, size: 13, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Text(
                            'Recipient: ${trig['recipient']}',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // ==========================================================================
  // TAB 4: HR BEST PRACTICES & FAQS
  // ==========================================================================
  Widget _buildFaqTab(bool isDark) {
    final faqs = [
      {
        'q': 'How do I complete onboarding if a candidate has pending documents on Day 1?',
        'a': 'The system includes an Authorized Completion Guard. If mandatory documents or tasks remain pending, clicking "Complete Onboarding" will prompt for an authorized administrative override reason. Once entered (min 5 characters), the override is logged in the compliance audit trail and onboarding is finalized.',
      },
      {
        'q': 'How do I advance a candidate through the pipeline stages?',
        'a': 'There are three easy ways:\n1. Click the Stage Chip with the pencil icon directly in the New Joiners table.\n2. Open the 360 Detail Drawer and click "Advance Stage".\n3. Click "Pipeline Workspace" in the header to drag-and-drop candidates across stages.',
      },
      {
        'q': 'What happens when an uploaded document is rejected by HR?',
        'a': 'When rejecting a document in the 360 Detail Drawer, HR must specify a rejection reason (e.g., "Scan blurry", "Signature missing"). The candidate status updates to "Rejected", and you can send a reminder email highlighting the rejection reason so they can re-upload.',
      },
      {
        'q': 'How do I reschedule a candidate\'s joining date?',
        'a': 'Open the candidate\'s 360 Detail Drawer and click "Reschedule". Select the revised date and input the reason. The system updates the joining calendar and optionally alerts the candidate and department head.',
      },
      {
        'q': 'How can I export reports for management or audits?',
        'a': 'Click the 3-dots icon in the top header and select "Export CSV Report" to download all filtered records. For department-level analytics and completion metrics, click "View Report →" on the Onboarding by Department card.',
      },
      {
        'q': 'How do I add a new hire directly without a prior recruitment candidate?',
        'a': 'Click "+ Add New Hire" in the top header. You can select an eligible candidate from the recruitment pipeline, or choose "Direct Onboarding" to enter details directly and assign a department template.',
      },
    ];

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        ...faqs.map((faq) => Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF13182C) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.question_mark_rounded, color: Color(0xFF4F46E5), size: 14),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          faq['q']!,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.only(left: 32),
                    child: Text(
                      faq['a']!,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            )),
      ],
    );
  }

  // ==========================================================================
  // FOOTER ACTIONS
  // ==========================================================================
  Widget _buildDialogFooter(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13182C) : const Color(0xFFF8FAFC),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(16),
          bottomRight: Radius.circular(16),
        ),
        border: Border(
          top: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (widget.onOpenPipeline != null)
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onOpenPipeline!();
                  },
                  icon: const Icon(Icons.view_kanban_outlined, size: 15),
                  label: const Text('Open Pipeline Workspace', style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                ),
              const SizedBox(width: 10),
              if (widget.onAddNewHire != null)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onAddNewHire!();
                  },
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 15, color: Colors.white),
                  label: const Text('Add New Hire', style: TextStyle(color: Colors.white, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  ),
                ),
            ],
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close Guide', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
