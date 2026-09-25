import 'package:flutter/material.dart';
import 'package:edu_shamiit_core/services/api_service.dart';
import 'package:edu_shamiit_admin/services/hr_lookup_helper.dart';
import 'package:intl/intl.dart';
import 'onboarding_document_viewer_dialog.dart';
import 'onboarding_stage_transition_dialog.dart';

class OnboardingDetailDrawer extends StatefulWidget {
  final String onboardingId;
  final VoidCallback onActionCompleted;
  final VoidCallback? onClose;

  const OnboardingDetailDrawer({
    super.key,
    required this.onboardingId,
    required this.onActionCompleted,
    this.onClose,
  });

  @override
  State<OnboardingDetailDrawer> createState() => _OnboardingDetailDrawerState();
}

class _OnboardingDetailDrawerState extends State<OnboardingDetailDrawer> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;
  bool _isLoading = true;
  String? _errorMessage;

  Map<String, dynamic> _data = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _fetchDetails();
  }

  @override
  void didUpdateWidget(covariant OnboardingDetailDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.onboardingId != widget.onboardingId) {
      _fetchDetails();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _api.get('/onboarding/records/${widget.onboardingId}', useCache: false);
      if (res['success'] == true) {
        setState(() {
          _data = res['data'] as Map<String, dynamic>? ?? {};
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = res['detail'] ?? 'Failed to load onboarding details.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('ApiException: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _verifyDocument(String docId, String docName) async {
    final remarksCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Verify Document: $docName'),
        content: TextField(
          controller: remarksCtrl,
          decoration: const InputDecoration(
            labelText: 'Verification Remarks (Optional)',
            hintText: 'e.g. Scanned copy verified against original',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Approve Document', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await _api.post('/onboarding/documents/$docId/verify', {
        'remarks': remarksCtrl.text.trim().isNotEmpty ? remarksCtrl.text.trim() : null
      });
      if (res['success'] == true) {
        _fetchDetails();
        widget.onActionCompleted();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Document "$docName" verified successfully!'), backgroundColor: const Color(0xFF10B981)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('ApiException: ', '')), backgroundColor: const Color(0xFFEF4444)),
      );
    }
  }

  Future<void> _rejectDocument(String docId, String docName) async {
    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reject Document: $docName'),
        content: TextField(
          controller: reasonCtrl,
          decoration: const InputDecoration(
            labelText: 'Mandatory Rejection Reason *',
            hintText: 'e.g. Image blurry, signature missing, wrong format',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () {
              if (reasonCtrl.text.trim().length < 3) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Please provide a valid reason.')));
                return;
              }
              Navigator.of(ctx).pop(true);
            },
            child: const Text('Reject Document', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await _api.post('/onboarding/documents/$docId/reject', {
        'reason': reasonCtrl.text.trim()
      });
      if (res['success'] == true) {
        _fetchDetails();
        widget.onActionCompleted();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Document "$docName" marked as rejected.'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('ApiException: ', '')), backgroundColor: const Color(0xFFEF4444)),
      );
    }
  }

  Future<void> _toggleTaskStatus(String taskId, String currentStatus) async {
    final newStatus = currentStatus == 'Completed' ? 'In Progress' : 'Completed';
    try {
      final res = await _api.patch('/onboarding/tasks/$taskId', {'status': newStatus});
      if (res['success'] == true) {
        _fetchDetails();
        widget.onActionCompleted();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('ApiException: ', '')), backgroundColor: const Color(0xFFEF4444)),
      );
    }
  }

  Future<void> _rescheduleJoining() async {
    DateTime newDate = DateTime.now().add(const Duration(days: 5));
    final reasonCtrl = TextEditingController();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Reschedule Joining Date'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select New Expected Joining Date *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: newDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 180)),
                  );
                  if (picked != null) {
                    setDialogState(() => newDate = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(DateFormat('dd MMMM yyyy').format(newDate)),
                      const Icon(Icons.calendar_month_rounded, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Reason for Rescheduling *',
                  hintText: 'e.g. Relocation delay requested by candidate',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (reasonCtrl.text.trim().isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Reason is required.')));
                  return;
                }
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Confirm Reschedule'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    try {
      final res = await _api.post('/onboarding/records/${widget.onboardingId}/joining', {
        'joining_status': 'Rescheduled',
        'expected_joining_date': DateFormat('yyyy-MM-dd').format(newDate),
        'reschedule_reason': reasonCtrl.text.trim(),
      });
      if (res['success'] == true) {
        _fetchDetails();
        widget.onActionCompleted();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Joining date rescheduled successfully.'), backgroundColor: Color(0xFF10B981)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('ApiException: ', '')), backgroundColor: const Color(0xFFEF4444)),
      );
    }
  }

  void _openStageTransitionDialog() {
    final onb = _data['onboarding'] as Map<String, dynamic>? ?? {};
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => OnboardingStageTransitionDialog(
        onboardingId: widget.onboardingId,
        candidateName: onb['candidate_name'] ?? 'New Hire',
        onboardingCode: onb['onboarding_code'] ?? 'EMP',
        designation: onb['designation'] ?? 'Staff',
        department: onb['department'] ?? 'Academics',
        currentStage: onb['stage'] ?? 'Offer Accepted',
        onStageChanged: () {
          _fetchDetails();
          widget.onActionCompleted();
        },
      ),
    );
  }

  Future<void> _sendReminderDialog() async {
    final onb = _data['onboarding'] as Map<String, dynamic>? ?? {};
    final candidateName = onb['candidate_name'] ?? 'Candidate';
    final email = onb['candidate_email'] ?? 'No email';
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
            Text('Send a detailed onboarding checklist reminder to $candidateName ($email).', style: const TextStyle(fontSize: 13)),
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
                hintText: 'e.g. Please submit pending certificates before Friday.',
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
      final res = await _api.post('/onboarding/records/${widget.onboardingId}/reminder', {
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
      _fetchDetails();
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

  Future<void> _confirmCandidateJoined() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Candidate Joined'),
        content: const Text(
          'Are you sure you want to mark this candidate as Joined? This confirms employee presence and updates joining status.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirm Joined', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final res = await _api.post('/onboarding/records/${widget.onboardingId}/joining', {
        'joining_status': 'Joined',
        'actual_joining_date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      });
      if (res['success'] == true) {
        _fetchDetails();
        widget.onActionCompleted();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Candidate marked as Joined!'), backgroundColor: Color(0xFF10B981)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('ApiException: ', '')), backgroundColor: const Color(0xFFEF4444)),
      );
    }
  }

  Future<void> _completeOnboarding() async {
    final completionGuard = _data['completion_guard'] as Map<String, dynamic>? ?? {};
    final isReady = completionGuard['is_ready_for_completion'] == true;
    final blockers = (completionGuard['blockers'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();

    if (!isReady) {
      final overrideReasonCtrl = TextEditingController();
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B)),
              SizedBox(width: 8),
              Text('Requirements Incomplete'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Onboarding has the following unresolved items:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              ...blockers.map((b) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• ', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                        Expanded(child: Text(b, style: const TextStyle(fontSize: 12))),
                      ],
                    ),
                  )),
              const SizedBox(height: 14),
              const Text(
                'To force complete onboarding as an authorized administrator, enter an override reason:',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: overrideReasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Override Reason *',
                  hintText: 'e.g. Principal approved provisional joining pending degree certificate',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
              onPressed: () {
                if (overrideReasonCtrl.text.trim().length < 5) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Please provide an override reason (min 5 chars).')),
                  );
                  return;
                }
                Navigator.of(ctx).pop(true);
              },
              child: const Text('Authorized Override & Complete', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );

      if (proceed != true) return;

      try {
        final res = await _api.post('/onboarding/records/${widget.onboardingId}/complete', {
          'override_blockers': true,
          'override_reason': overrideReasonCtrl.text.trim(),
        });
        if (res['success'] == true) {
          _fetchDetails();
          widget.onActionCompleted();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['message'] ?? 'Onboarding completed!'), backgroundColor: const Color(0xFF10B981)),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('ApiException: ', '')), backgroundColor: const Color(0xFFEF4444)),
        );
      }
      return;
    }

    // Direct clean complete
    try {
      final res = await _api.post('/onboarding/records/${widget.onboardingId}/complete', {
        'override_blockers': false,
      });
      if (res['success'] == true) {
        _fetchDetails();
        widget.onActionCompleted();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res['message'] ?? 'Onboarding completed!'), backgroundColor: const Color(0xFF10B981)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('ApiException: ', '')), backgroundColor: const Color(0xFFEF4444)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final onb = _data['onboarding'] as Map<String, dynamic>? ?? {};
    final progress = _data['progress'] as Map<String, dynamic>? ?? {};
    final overallPct = (progress['overall_pct'] as num?)?.toDouble() ?? 0.0;

    return Container(
      constraints: const BoxConstraints(maxWidth: 720),
      color: isDark ? const Color(0xFF0F172A) : Colors.white,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFEF4444))))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Drawer Header
                    _buildHeader(onb, overallPct, isDark),

                    // Tabs
                    Container(
                      decoration: BoxDecoration(
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
                        tabs: const [
                          Tab(text: 'Overview'),
                          Tab(text: 'Documents'),
                          Tab(text: 'Tasks'),
                          Tab(text: 'Joining'),
                          Tab(text: 'Communication'),
                          Tab(text: 'Activity'),
                        ],
                      ),
                    ),

                    // Tab Views
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildOverviewTab(onb, progress, isDark),
                          _buildDocumentsTab(isDark),
                          _buildTasksTab(isDark),
                          _buildJoiningTab(onb, isDark),
                          _buildCommunicationTab(onb, isDark),
                          _buildActivityTab(isDark),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildHeader(Map<String, dynamic> onb, double overallPct, bool isDark) {
    final status = onb['status'] ?? 'Pending';
    final candidateName = onb['candidate_name'] ?? 'New Hire';
    final designation = onb['designation'] ?? 'Employee';
    final code = onb['onboarding_code'] ?? '';
    final dept = onb['department'] ?? '';

    Color statusBg;
    Color statusFg;
    if (status == 'Completed') {
      statusBg = const Color(0xFF10B981).withValues(alpha: 0.1);
      statusFg = const Color(0xFF10B981);
    } else if (status == 'In Progress') {
      statusBg = const Color(0xFF3B82F6).withValues(alpha: 0.1);
      statusFg = const Color(0xFF3B82F6);
    } else {
      statusBg = const Color(0xFFF59E0B).withValues(alpha: 0.1);
      statusFg = const Color(0xFFF59E0B);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13182C) : const Color(0xFFF8FAFC),
        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                    child: Text(
                      candidateName.isNotEmpty ? candidateName[0].toUpperCase() : 'N',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            candidateName,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Outfit',
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(6)),
                            child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusFg)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$code • $designation • $dept',
                        style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () {
                  if (widget.onClose != null) {
                    widget.onClose!();
                  } else {
                    Navigator.of(context).maybePop();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Overall Progress Bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (overallPct / 100).clamp(0.0, 1.0),
                    backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF4F46E5)),
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$overallPct% Complete',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Quick Action Toolbar (Responsive Wrap)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.published_with_changes_rounded, size: 16),
                label: const Text('Advance Stage'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                onPressed: _openStageTransitionDialog,
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: const Text('Complete Onboarding'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                onPressed: _completeOnboarding,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_month_rounded, size: 16),
                label: const Text('Reschedule'),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                onPressed: _rescheduleJoining,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.notifications_active_outlined, size: 16),
                label: const Text('Send Reminder'),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                onPressed: _sendReminderDialog,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // OVERVIEW TAB
  Widget _buildOverviewTab(Map<String, dynamic> onb, Map<String, dynamic> progress, bool isDark) {
    final docs = progress['documents'] as Map<String, dynamic>? ?? {};
    final tasks = progress['tasks'] as Map<String, dynamic>? ?? {};
    final joining = progress['joining'] as Map<String, dynamic>? ?? {};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 4 Metric cards row with responsive layout
          LayoutBuilder(
            builder: (ctx, constraints) {
              final isNarrow = constraints.maxWidth < 580;
              if (isNarrow) {
                return Column(
                  children: [
                    Row(
                      children: [
                        _buildSmallStatCard('Documents', '${docs['verified'] ?? 0}/${docs['total'] ?? 0}', Icons.description_outlined, const Color(0xFF3B82F6), isDark),
                        const SizedBox(width: 10),
                        _buildSmallStatCard('Tasks', '${tasks['completed'] ?? 0}/${tasks['total'] ?? 0}', Icons.checklist_rounded, const Color(0xFF8B5CF6), isDark),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildSmallStatCard('Joining', joining['is_joined'] == true ? 'Joined' : 'Pending', Icons.event_available_rounded, const Color(0xFF10B981), isDark),
                        const SizedBox(width: 10),
                        _buildSmallStatCard(
                          'Stage',
                          onb['stage'] ?? 'Offer Accepted',
                          Icons.alt_route_rounded,
                          const Color(0xFFEC4899),
                          isDark,
                          onTap: _openStageTransitionDialog,
                          showEditIcon: true,
                        ),
                      ],
                    ),
                  ],
                );
              }
              return Row(
                children: [
                  _buildSmallStatCard('Documents', '${docs['verified'] ?? 0}/${docs['total'] ?? 0}', Icons.description_outlined, const Color(0xFF3B82F6), isDark),
                  const SizedBox(width: 10),
                  _buildSmallStatCard('Tasks', '${tasks['completed'] ?? 0}/${tasks['total'] ?? 0}', Icons.checklist_rounded, const Color(0xFF8B5CF6), isDark),
                  const SizedBox(width: 10),
                  _buildSmallStatCard('Joining', joining['is_joined'] == true ? 'Joined' : 'Pending', Icons.event_available_rounded, const Color(0xFF10B981), isDark),
                  const SizedBox(width: 10),
                  _buildSmallStatCard(
                    'Stage',
                    onb['stage'] ?? 'Offer Accepted',
                    Icons.alt_route_rounded,
                    const Color(0xFFEC4899),
                    isDark,
                    onTap: _openStageTransitionDialog,
                    showEditIcon: true,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),


          // Candidate Details Card
          _buildSectionHeader('Candidate Profile Information', Icons.badge_outlined),
          const SizedBox(height: 10),
          _buildInfoGrid([
            {'label': 'Full Name', 'value': onb['candidate_name'] ?? 'N/A'},
            {'label': 'Email Address', 'value': onb['candidate_email'] ?? 'N/A'},
            {'label': 'Phone Number', 'value': onb['candidate_phone'] ?? 'N/A'},
            {'label': 'Highest Qualification', 'value': onb['qualification'] ?? 'N/A'},
            {'label': 'Prior Experience', 'value': '${onb['experience_years'] ?? 0} Years'},
            {'label': 'Current Organization', 'value': onb['current_organization'] ?? 'None / Fresh'},
          ], isDark),
          const SizedBox(height: 20),

          // Job & Placement Information Card
          _buildSectionHeader('Placement & Joining Formalities', Icons.work_outline_rounded),
          const SizedBox(height: 10),
          _buildInfoGrid([
            {'label': 'Department', 'value': onb['department'] ?? 'Academics'},
            {'label': 'Designation', 'value': onb['designation'] ?? 'Teacher'},
            {'label': 'Employment Type', 'value': onb['employment_type'] ?? 'Full-time'},
            {'label': 'Expected Joining Date', 'value': onb['expected_joining_date']?.toString() ?? 'N/A'},
            {'label': 'Reporting Time & Place', 'value': '${onb['reporting_time'] ?? '09:00 AM'} (${onb['reporting_location'] ?? 'Main Campus'})'},
            {'label': 'Probation Period', 'value': '${onb['probation_period_months'] ?? 6} Months'},
            {'label': 'HR Owner', 'value': onb['hr_owner_name'] ?? 'HR Operations'},
            {'label': 'Joining Status', 'value': onb['joining_status'] ?? 'Expected'},
          ], isDark),
        ],
      ),
    );
  }

  // DOCUMENTS TAB
  Widget _buildDocumentsTab(bool isDark) {
    final docs = _data['documents'] as List<dynamic>? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Required Documents (${docs.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Document'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                onPressed: () async {
                  final nameCtrl = TextEditingController();
                  final added = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Add Required Document'),
                      content: TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(labelText: 'Document Name', hintText: 'e.g. Police Clearance Certificate'),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                        ElevatedButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('Add to Checklist'),
                        ),
                      ],
                    ),
                  );
                  if (added == true && nameCtrl.text.trim().isNotEmpty) {
                    await _api.post('/onboarding/records/${widget.onboardingId}/documents', {'document_name': nameCtrl.text.trim()});
                    _fetchDetails();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          ...docs.map((d) {
            final status = d['status'] ?? 'Pending';
            final isVerified = status == 'Verified';
            final isRejected = status == 'Rejected';

            Color badgeBg;
            Color badgeFg;
            if (isVerified) {
              badgeBg = const Color(0xFF10B981).withValues(alpha: 0.1);
              badgeFg = const Color(0xFF10B981);
            } else if (isRejected) {
              badgeBg = const Color(0xFFEF4444).withValues(alpha: 0.1);
              badgeFg = const Color(0xFFEF4444);
            } else {
              badgeBg = const Color(0xFFF59E0B).withValues(alpha: 0.1);
              badgeFg = const Color(0xFFF59E0B);
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF13182C) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.description_outlined, color: Color(0xFF4F46E5), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(d['document_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            if (d['is_mandatory'] == true) ...[
                              const SizedBox(width: 6),
                              const Text('*', style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold)),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Required for: ${d['required_for'] ?? 'All'} ${d['rejection_reason'] != null ? '• Rejection Reason: ${d['rejection_reason']}' : ''}',
                          style: TextStyle(fontSize: 11, color: isRejected ? const Color(0xFFEF4444) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(6)),
                    child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badgeFg)),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.visibility_outlined, color: Color(0xFF4F46E5), size: 18),
                    tooltip: 'View / Preview Document',
                    onPressed: () {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) => OnboardingDocumentViewerDialog(
                          document: d,
                          onDocumentUpdated: () {
                            _fetchDetails();
                            widget.onActionCompleted();
                          },
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.upload_file_rounded, color: Color(0xFF0EA5E9), size: 18),
                    tooltip: 'Upload Document (HR on behalf of Candidate)',
                    onPressed: () {
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (ctx) => OnboardingDocumentViewerDialog(
                          document: d,
                          onDocumentUpdated: () {
                            _fetchDetails();
                            widget.onActionCompleted();
                          },
                        ),
                      );
                    },
                  ),
                  if (!isVerified) ...[
                    IconButton(
                      icon: const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 18),
                      tooltip: 'Approve / Verify',
                      onPressed: () => _verifyDocument(d['id'].toString(), d['document_name'] ?? 'Document'),
                    ),
                    IconButton(
                      icon: const Icon(Icons.highlight_off_rounded, color: Color(0xFFEF4444), size: 18),
                      tooltip: 'Reject',
                      onPressed: () => _rejectDocument(d['id'].toString(), d['document_name'] ?? 'Document'),
                    ),
                  ] else
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 18),
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // TASKS TAB
  Widget _buildTasksTab(bool isDark) {
    final tasks = _data['tasks'] as List<dynamic>? ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Checklist Tasks (${tasks.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Task'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                ),
                onPressed: () async {
                  final titleCtrl = TextEditingController();
                  final categories = await HRLookupHelper.instance.getLookupLabels('ONBOARDING_TASK_CATEGORY', forceRefresh: true);
                  String cat = categories.isNotEmpty ? categories.first : 'HR';
                  String team = '$cat Team';
                  if (!mounted) return;
                  final added = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => StatefulBuilder(
                      builder: (ctx, setDState) => AlertDialog(
                        title: const Text('Add Onboarding Task'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextField(
                              controller: titleCtrl,
                              decoration: const InputDecoration(labelText: 'Task Title', hintText: 'e.g. Issue Campus ID Card'),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: categories.contains(cat) ? cat : (categories.isNotEmpty ? categories.first : null),
                              items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setDState(() {
                                    cat = val;
                                    team = '$val Team';
                                  });
                                }
                              },
                              decoration: const InputDecoration(labelText: 'Category'),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                          ElevatedButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('Add Task'),
                          ),
                        ],
                      ),
                    ),
                  );

                  if (added == true && titleCtrl.text.trim().isNotEmpty) {
                    await _api.post('/onboarding/records/${widget.onboardingId}/tasks', {
                      'title': titleCtrl.text.trim(),
                      'category': cat,
                      'assigned_team': team,
                    });
                    _fetchDetails();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          ...tasks.map((t) {
            final isCompleted = t['status'] == 'Completed';
            final isOverdue = t['status'] == 'Overdue';

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF13182C) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: isCompleted,
                    activeColor: const Color(0xFF10B981),
                    onChanged: (_) => _toggleTaskStatus(t['id'].toString(), t['status'] ?? 'Pending'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          t['title'] ?? '',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            decoration: isCompleted ? TextDecoration.lineThrough : null,
                            color: isCompleted ? (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)) : null,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${t['category']} • Assigned to: ${t['assigned_team'] ?? 'Team'} • Due: ${t['due_date'] ?? 'On joining'}',
                          style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? const Color(0xFF10B981).withValues(alpha: 0.1)
                          : (isOverdue ? const Color(0xFFEF4444).withValues(alpha: 0.1) : const Color(0xFF3B82F6).withValues(alpha: 0.1)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      t['status'] ?? 'Pending',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isCompleted ? const Color(0xFF10B981) : (isOverdue ? const Color(0xFFEF4444) : const Color(0xFF3B82F6)),
                      ),
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

  // JOINING TAB
  Widget _buildJoiningTab(Map<String, dynamic> onb, bool isDark) {
    final joiningStatus = onb['joining_status'] ?? 'Expected';
    final isJoined = joiningStatus == 'Joined';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF13182C) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Joining Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: isJoined ? const Color(0xFF10B981).withValues(alpha: 0.1) : const Color(0xFF3B82F6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        joiningStatus,
                        style: TextStyle(fontWeight: FontWeight.bold, color: isJoined ? const Color(0xFF10B981) : const Color(0xFF3B82F6)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _buildReviewRow('Expected Joining Date', onb['expected_joining_date']?.toString() ?? 'N/A'),
                _buildReviewRow('Actual Joining Date', onb['actual_joining_date']?.toString() ?? (isJoined ? 'Recorded' : 'Pending Arrival')),
                _buildReviewRow('Reporting Time', onb['reporting_time'] ?? '09:00 AM'),
                _buildReviewRow('Reporting Location', onb['reporting_location'] ?? 'Main Campus - HR Office'),
                if (onb['reschedule_reason'] != null)
                  _buildReviewRow('Last Reschedule Reason', onb['reschedule_reason'].toString()),
                if (onb['no_show_reason'] != null)
                  _buildReviewRow('No Show Reason', onb['no_show_reason'].toString()),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Actions
          Row(
            children: [
              if (!isJoined) ...[
                ElevatedButton.icon(
                  icon: const Icon(Icons.how_to_reg_rounded, size: 16),
                  label: const Text('Confirm Candidate Joined'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onPressed: _confirmCandidateJoined,
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.event_repeat_rounded, size: 16),
                  label: const Text('Reschedule Joining Date'),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                  onPressed: _rescheduleJoining,
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  icon: const Icon(Icons.person_off_outlined, size: 16),
                  label: const Text('Mark No Show'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFEF4444)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onPressed: () async {
                    final reasonCtrl = TextEditingController();
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Mark Candidate as No-Show'),
                        content: TextField(
                          controller: reasonCtrl,
                          decoration: const InputDecoration(labelText: 'No Show Reason *', hintText: 'Candidate did not report on expected date'),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text('Confirm No Show', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await _api.post('/onboarding/records/${widget.onboardingId}/joining', {
                        'joining_status': 'No Show',
                        'no_show_reason': reasonCtrl.text.trim().isNotEmpty ? reasonCtrl.text.trim() : 'Candidate did not report on expected joining date',
                      });
                      _fetchDetails();
                    }
                  },
                ),
              ] else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.verified, color: Color(0xFF10B981), size: 18),
                      SizedBox(width: 8),
                      Text('Candidate has officially joined the institution.', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // COMMUNICATION TAB
  Widget _buildCommunicationTab(Map<String, dynamic> onb, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Employee Communication History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFF4F46E5), child: Icon(Icons.email_outlined, color: Colors.white, size: 18)),
            title: const Text('Welcome to EduSHAMIIT Email', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: Text('Sent to ${onb['candidate_email'] ?? 'candidate'} upon offer acceptance', style: const TextStyle(fontSize: 11)),
            trailing: const Text('Sent', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11)),
          ),
          const Divider(height: 1),
          const ListTile(
            leading: CircleAvatar(backgroundColor: Color(0xFF3B82F6), child: Icon(Icons.notifications_active_outlined, color: Colors.white, size: 18)),
            title: Text('Document Submission Reminder', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            subtitle: Text('Automated reminder sent for pending documents verification', style: TextStyle(fontSize: 11)),
            trailing: Text('Delivered', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  // ACTIVITY TAB
  Widget _buildActivityTab(bool isDark) {
    final activities = _data['activities'] as List<dynamic>? ?? [];

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: activities.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, idx) {
        final act = activities[idx];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.history_rounded, color: Color(0xFF4F46E5), size: 14),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_formatAction(act['action']?.toString()), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(act['description'] ?? '', style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569))),
                  const SizedBox(height: 2),
                  Text(act['created_at']?.toString() ?? '', style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSmallStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    bool isDark, {
    VoidCallback? onTap,
    bool showEditIcon = false,
  }) {
    final cardContent = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13182C) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: onTap != null ? color.withValues(alpha: 0.4) : (isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
            child: Icon(icon, color: color, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (showEditIcon) ...[
            const SizedBox(width: 4),
            Icon(Icons.edit_outlined, size: 13, color: color),
          ],
        ],
      ),
    );

    return Expanded(
      child: Tooltip(
        message: onTap != null ? '$title: $value (Click to transition)' : '$title: $value',
        child: onTap != null
            ? InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(10),
                child: cardContent,
              )
            : cardContent,
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: const Color(0xFF4F46E5)),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildInfoGrid(List<Map<String, String>> items, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF13182C) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: items.map((it) => _buildReviewRow(it['label']!, it['value']!)).toList(),
      ),
    );
  }

  Widget _buildReviewRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }


  String _formatAction(String? rawAction) {
    if (rawAction == null || rawAction.trim().isEmpty) return 'Action';
    return rawAction
        .replaceAll('_', ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }
}
