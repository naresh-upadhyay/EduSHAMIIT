import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:edu_shamiit_core/services/api_service.dart';
import 'request_acknowledgement_dialog.dart';
import 'create_policy_dialog.dart';
import 'policy_acknowledgement_dialog.dart';
import 'searchable_reviewer_picker.dart';

class PolicyDetailDrawer extends StatefulWidget {
  final String policyId;
  final VoidCallback onPolicyUpdated;

  const PolicyDetailDrawer({
    super.key,
    required this.policyId,
    required this.onPolicyUpdated,
  });

  @override
  State<PolicyDetailDrawer> createState() => _PolicyDetailDrawerState();
}

class _PolicyDetailDrawerState extends State<PolicyDetailDrawer> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;

  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _policyData;
  List<dynamic> _versions = [];
  List<dynamic> _acknowledgements = [];
  List<dynamic> _activity = [];
  Map<String, dynamic> _ackSummary = {};
  String? _remindingAckId;
  bool _isRemindingAll = false;

  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _fetchDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchDetails() async {
    setState(() => _isLoading = true);
    try {
      final res = await _api.get('/hr/policies/${widget.policyId}', useCache: false);
      if (res['success'] == true) {
        final data = res['data'] as Map<String, dynamic>;
        final policy = (data['policy'] is Map ? Map<String, dynamic>.from(data['policy']) : data);
        setState(() {
          _policyData = policy;
          _versions = data['versions'] ?? [];
          _acknowledgements = data['acknowledgements'] ?? [];
          _activity = data['activity'] ?? data['activity_timeline'] ?? [];
          _ackSummary = data['acknowledgements_summary'] ?? {};
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _transitionStatus(String action, {Map<String, dynamic>? body}) async {
    try {
      final res = await _api.post('/hr/policies/${widget.policyId}/$action', body ?? {});
      if (res['success'] == true) {
        widget.onPolicyUpdated();
        await _fetchDetails();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Action $action completed successfully'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showRejectDialog() async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Policy Revision'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please provide a mandatory reason for rejecting this policy revision:'),
              const SizedBox(height: 12),
              TextFormField(
                controller: reasonController,
                validator: (v) => v == null || v.trim().isEmpty ? 'Rejection reason is required' : null,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Rejection Reason *',
                  hintText: 'e.g. Needs updated biohazard laboratory protocols...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Reject Policy', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _transitionStatus('reject', body: {'rejection_reason': reasonController.text.trim()});
    }
  }

  Future<void> _showSubmitForReviewDialog() async {
    final commentsController = TextEditingController();
    final searchController = TextEditingController();
    Map<String, dynamic>? selectedReviewer;
    List<Map<String, dynamic>> candidateReviewers = [];

    try {
      final res = await _api.get('/hr/employees', query: {'limit': 50}, useCache: false);
      if (res['success'] == true && res['data'] is List) {
        candidateReviewers = List<Map<String, dynamic>>.from(res['data']);
      }
    } catch (_) {}

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.rate_review_rounded, color: Color(0xFF4F46E5), size: 20),
              ),
              const SizedBox(width: 10),
              const Text('Submit Policy for Review', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: math.min(520.0, MediaQuery.of(context).size.width * 0.9),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Select the designated reviewer/approver who will evaluate this policy before it is published to all institutional users:',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),
                  const Text('Select Reviewer / Approver *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  SearchableReviewerPicker(
                    candidateReviewers: candidateReviewers,
                    selectedReviewer: selectedReviewer,
                    onReviewerSelected: (emp) {
                      setModalState(() {
                        selectedReviewer = emp;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Review Notes / Comments', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: commentsController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'e.g. Please review section 3 regarding institutional biohazard compliance...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton.icon(
              onPressed: () {
                if (selectedReviewer == null && searchController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please select or specify a reviewer for this policy.'), backgroundColor: Colors.orange),
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              icon: const Icon(Icons.send_rounded, size: 14, color: Colors.white),
              label: const Text('Submit for Review', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      await _transitionStatus('submit-review', body: {
        'reviewer_id': selectedReviewer?['id'],
        'reviewer_name': selectedReviewer?['full_name'] ?? selectedReviewer?['email'] ?? searchController.text.trim(),
        'reviewer_role': selectedReviewer?['role'] ?? 'Reviewer',
        'comments': commentsController.text.trim(),
      });
    }
  }

  Future<void> _showNewVersionDialog() async {
    final verController = TextEditingController();
    final summaryController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool requireAcks = true;

    final currentVer = _policyData?['current_version'] ?? '1.0';
    final parts = currentVer.toString().split('.');
    String suggestedVer = '2.0';
    if (parts.length >= 2) {
      final major = int.tryParse(parts[0]) ?? 1;
      suggestedVer = '${major + 1}.0';
    }
    verController.text = suggestedVer;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Create New Policy Version'),
          content: Form(
            key: formKey,
            child: SizedBox(
              width: 480,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Active policy versions are never overwritten destructively. Enter new version details:'),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: verController,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Version number required' : null,
                    decoration: const InputDecoration(labelText: 'Version Number *', hintText: 'e.g. 2.0', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: summaryController,
                    validator: (v) => v == null || v.trim().isEmpty ? 'Change summary required' : null,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Change Summary *', hintText: 'Summary of amendments in this version', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Require New Acknowledgement'),
                    subtitle: const Text('Re-dispatch acknowledgement requirement to staff for this new version.'),
                    value: requireAcks,
                    onChanged: (v) => setModalState(() => requireAcks = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: const Text('Create Version'),
            ),
          ],
        ),
      ),
    );

    if (confirm == true) {
      try {
        final res = await _api.post('/hr/policies/${widget.policyId}/versions', {
          'version_number': verController.text.trim(),
          'change_summary': summaryController.text.trim(),
          'require_new_acknowledgements': requireAcks,
        });
        if (res['success'] == true) {
          widget.onPolicyUpdated();
          await _fetchDetails();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('New version created!'), backgroundColor: Colors.green),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create version: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _sendReminder(String ackId) async {
    setState(() => _remindingAckId = ackId);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await _api.post('/hr/acknowledgements/$ackId/remind', {});
      if (!mounted) return;
      if (res['success'] == true) {
        final msg = res['message'] ?? 'Reminder sent to employee!';
        final emailSent = res['email_sent'] == true;
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  emailSent ? Icons.mark_email_read_rounded : Icons.notifications_active_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500))),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            duration: const Duration(seconds: 4),
          ),
        );
        _fetchDetails();
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Failed to send reminder'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _remindingAckId = null);
    }
  }

  Future<void> _sendRemindAll() async {
    final pendingCount = _acknowledgements.where((a) => a['status'] != 'ACKNOWLEDGED').length;
    if (pendingCount == 0) return;

    setState(() => _isRemindingAll = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await _api.post('/hr/policies/${widget.policyId}/acknowledgements/remind-all', {});
      if (!mounted) return;
      if (res['success'] == true) {
        final msg = res['message'] ?? 'Reminders dispatched to pending employees!';
        messenger.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.mark_email_read_rounded, color: Colors.white, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500))),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            duration: const Duration(seconds: 4),
          ),
        );
        _fetchDetails();
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Failed to dispatch bulk reminders'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red, behavior: SnackBarBehavior.floating),
      );
    } finally {
      if (mounted) setState(() => _isRemindingAll = false);
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toUpperCase()) {
      case 'ACTIVE':
      case 'PUBLISHED':
      case 'APPROVED':
        return const Color(0xFF10B981);
      case 'PENDING_REVIEW':
      case 'SCHEDULED':
        return const Color(0xFFF59E0B);
      case 'REJECTED':
      case 'EXPIRED':
        return const Color(0xFFEF4444);
      case 'ARCHIVED':
        return const Color(0xFF64748B);
      case 'DRAFT':
      default:
        return const Color(0xFF4F46E5);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: 680,
      color: isDark ? const Color(0xFF13182C) : Colors.white,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text('Error: $_errorMessage'))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Drawer Header
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                        border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
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
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(_policyData?['status']).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _policyData?['status'] ?? 'DRAFT',
                                      style: TextStyle(
                                        color: _getStatusColor(_policyData?['status']),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'v${_policyData?['current_version'] ?? '1.0'}',
                                      style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _policyData?['title'] ?? 'Policy Details',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_policyData?['policy_code'] ?? ''} · ${_policyData?['category_name'] ?? ''} · Custodian: ${_policyData?['policy_owner_name'] ?? _policyData?['policy_owner'] ?? 'HR'}',
                            style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                          const SizedBox(height: 16),
                          // Lifecycle Action Bar
                          _buildActionBar(),
                        ],
                      ),
                    ),
                    // Navigation Tabs
                    TabBar(
                      controller: _tabController,
                      indicatorColor: const Color(0xFF4F46E5),
                      labelColor: const Color(0xFF4F46E5),
                      unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      tabs: const [
                        Tab(text: 'Overview'),
                        Tab(text: 'Content'),
                        Tab(text: 'Versions'),
                        Tab(text: 'Sign-offs'),
                        Tab(text: 'Activity'),
                      ],
                    ),
                    // Tab Contents
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildOverviewTab(isDark),
                          _buildContentTab(isDark),
                          _buildVersionsTab(isDark),
                          _buildAcknowledgementsTab(isDark),
                          _buildActivityTab(isDark),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildActionBar() {
    final status = _policyData?['status']?.toString().toUpperCase() ?? 'DRAFT';

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (status == 'DRAFT' || status == 'REJECTED') ...[
          ElevatedButton.icon(
            onPressed: _showSubmitForReviewDialog,
            icon: const Icon(Icons.send_rounded, size: 14, color: Colors.white),
            label: const Text('Submit for Review', style: TextStyle(color: Colors.white, fontSize: 12)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
          ),
        ],
        if (status == 'PENDING_REVIEW') ...[
          ElevatedButton.icon(
            onPressed: () => _transitionStatus('approve'),
            icon: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
            label: const Text('Approve', style: TextStyle(color: Colors.white, fontSize: 12)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
          ),
          ElevatedButton.icon(
            onPressed: () => _transitionStatus('publish'),
            icon: const Icon(Icons.publish_rounded, size: 14, color: Colors.white),
            label: const Text('Approve & Publish', style: TextStyle(color: Colors.white, fontSize: 12)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
          ),
          OutlinedButton.icon(
            onPressed: _showRejectDialog,
            icon: const Icon(Icons.close_rounded, size: 14, color: Colors.red),
            label: const Text('Reject', style: TextStyle(color: Colors.red, fontSize: 12)),
          ),
        ],
        if (status == 'APPROVED') ...[
          ElevatedButton.icon(
            onPressed: () => _transitionStatus('publish'),
            icon: const Icon(Icons.publish_rounded, size: 14, color: Colors.white),
            label: const Text('Publish & Activate', style: TextStyle(color: Colors.white, fontSize: 12)),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
          ),
        ],
        if (status == 'ACTIVE' || status == 'PUBLISHED') ...[
          OutlinedButton.icon(
            onPressed: _showNewVersionDialog,
            icon: const Icon(Icons.add_to_photos_outlined, size: 14),
            label: const Text('New Version', style: TextStyle(fontSize: 12)),
          ),
          OutlinedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => RequestAcknowledgementDialog(
                  preselectedPolicyId: widget.policyId,
                  preselectedPolicyTitle: _policyData?['title'],
                  preselectedVersion: _policyData?['current_version'] ?? '1.0',
                  onRequested: _fetchDetails,
                ),
              );
            },
            icon: const Icon(Icons.how_to_reg_outlined, size: 14),
            label: const Text('Request Sign-off', style: TextStyle(fontSize: 12)),
          ),
          OutlinedButton.icon(
            onPressed: () => _transitionStatus('archive'),
            icon: const Icon(Icons.archive_outlined, size: 14, color: Colors.amber),
            label: const Text('Archive', style: TextStyle(color: Colors.amber, fontSize: 12)),
          ),
        ],
        OutlinedButton.icon(
          onPressed: () {
            showDialog(
              context: context,
              builder: (_) => CreatePolicyDialog(
                initialPolicy: _policyData,
                onPolicyCreated: () {
                  widget.onPolicyUpdated();
                  _fetchDetails();
                },
              ),
            );
          },
          icon: const Icon(Icons.edit_outlined, size: 14),
          label: const Text('Edit Policy', style: TextStyle(fontSize: 12)),
        ),
      ],
    );
  }

  Widget _buildOverviewTab(bool isDark) {
    final pendingCount = _ackSummary['pending'] ?? _acknowledgements.where((a) => a['status'] != 'ACKNOWLEDGED').length;
    final ackCount = _ackSummary['total_acknowledged'] ?? _ackSummary['acknowledged'] ?? _acknowledgements.where((a) => a['status'] == 'ACKNOWLEDGED').length;
    final totalAssigned = _ackSummary['total_required'] ?? _ackSummary['total_assigned'] ?? _acknowledgements.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pending Sign-offs Alert Banner
          if (pendingCount > 0) ...[
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.pending_actions_rounded, color: Color(0xFFF59E0B), size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$pendingCount Sign-off(s) Pending Review',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Assigned employees are required to review this policy and submit digital sign-off.',
                          style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      _tabController.animateTo(3); // Jump to Sign-offs tab (index 3)
                    },
                    icon: const Icon(Icons.rate_review_rounded, size: 14, color: Colors.white),
                    label: const Text('View Sign-offs', style: TextStyle(fontSize: 12, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF59E0B),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Compliance Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF4F46E5).withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF4F46E5).withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Staff Compliance Progress', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 4),
                      Text(
                        '$ackCount acknowledged out of $totalAssigned assigned employees.',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: ((_ackSummary['completion_percentage'] ?? (totalAssigned > 0 ? (ackCount / totalAssigned * 100.0) : 0)) as num).toDouble() / 100.0,
                        backgroundColor: const Color(0xFFCBD5E1),
                        color: const Color(0xFF10B981),
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Text(
                  '${_ackSummary['completion_percentage'] ?? (totalAssigned > 0 ? (ackCount / totalAssigned * 100.0).toStringAsFixed(1) : 0)}%',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text('Policy Metadata', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          _buildInfoRow('Description', _policyData?['description'] ?? 'No description provided.'),
          _buildInfoRow('Applicability', '${_policyData?['audience_type'] ?? _policyData?['applicability_type'] ?? 'Entire Institute'}${_policyData?['department'] != null && _policyData!['department'] != 'All Departments' ? " (${_policyData!['department']})" : ""}'),
          if (_policyData?['reviewer_name'] != null || _policyData?['reviewer_id'] != null)
            _buildInfoRow('Assigned Reviewer', '${_policyData?['reviewer_name'] ?? 'Designated Reviewer'}${_policyData?['reviewer_role'] != null ? " (${_policyData!['reviewer_role']})" : ""}'),
          if (_policyData?['submitted_for_review_at'] != null)
            _buildInfoRow('Submitted For Review', _dateFormat.format(DateTime.parse(_policyData!['submitted_for_review_at'].toString()))),
          if (_policyData?['approved_by_name'] != null)
            _buildInfoRow('Approved By', _policyData!['approved_by_name']),
          if (_policyData?['rejection_reason'] != null && _policyData!['rejection_reason'].toString().isNotEmpty)
            _buildInfoRow('Rejection Reason', _policyData!['rejection_reason']),
          _buildInfoRow('Effective Date', _policyData?['effective_date'] != null ? _dateFormat.format(DateTime.parse(_policyData!['effective_date'].toString())) : 'Immediate'),
          _buildInfoRow('Next Review Date', _policyData?['review_date'] != null ? _dateFormat.format(DateTime.parse(_policyData!['review_date'].toString())) : 'Not scheduled'),
          _buildInfoRow('Review Frequency', _policyData?['review_frequency_months'] != null ? "${_policyData!['review_frequency_months']} Months" : (_policyData?['review_frequency'] ?? 'Annual')),
          _buildInfoRow('Mandatory Compliance', _policyData?['acknowledgement_mandatory'] == true ? 'Strictly Mandatory' : 'Optional'),
          _buildInfoRow('Created Date', _policyData?['created_at'] != null ? _dateFormat.format(DateTime.parse(_policyData!['created_at'].toString())) : '-'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, dynamic value) {
    String displayValue = '-';
    if (value is List) {
      displayValue = value.isEmpty ? 'None' : value.map((e) => e.toString()).join(', ');
    } else if (value != null && value.toString().trim().isNotEmpty) {
      displayValue = value.toString();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(displayValue, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildContentTab(bool isDark) {
    final content = _policyData?['content_html'];
    final hasContent = content != null && content.toString().trim().isNotEmpty;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
        ),
        child: hasContent
            ? SelectableText(
                content.toString().replaceAll(RegExp(r'<[^>]*>'), '\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim(),
                style: const TextStyle(fontSize: 13, height: 1.6),
              )
            : Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(Icons.article_outlined, size: 48, color: isDark ? const Color(0xFF475569) : const Color(0xFF94A3B8)),
                      const SizedBox(height: 12),
                      Text(
                        'No policy content authored yet.',
                        style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 13),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => CreatePolicyDialog(
                              initialPolicy: _policyData,
                              onPolicyCreated: () {
                                widget.onPolicyUpdated();
                                _fetchDetails();
                              },
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit_note_rounded, size: 16),
                        label: const Text('Author Policy Content'),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildVersionsTab(bool isDark) {
    if (_versions.isEmpty) {
      return const Center(child: Text('No previous versions.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: _versions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final v = _versions[index];
        final isCurrent = v['version_number'] == _policyData?['current_version'];

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isCurrent ? const Color(0xFF4F46E5) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              width: isCurrent ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text('Version ${v['version_number']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      if (isCurrent) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: const Color(0xFF4F46E5), borderRadius: BorderRadius.circular(4)),
                          child: const Text('CURRENT ACTIVE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    v['created_at'] != null ? _dateFormat.format(DateTime.parse(v['created_at'])) : '',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                v['change_summary'] ?? 'Initial version creation.',
                style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAcknowledgementsTab(bool isDark) {
    if (_acknowledgements.isEmpty) {
      return const Center(child: Text('No employees assigned for acknowledgement yet.'));
    }

    final totalCount = _acknowledgements.length;
    final signedCount = _acknowledgements.where((a) => a['status'] == 'ACKNOWLEDGED').length;
    final pendingCount = totalCount - signedCount;

    return Column(
      children: [
        // Summary & Remind All Action Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (pendingCount > 0 ? const Color(0xFFF59E0B) : const Color(0xFF10B981)).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$signedCount of $totalCount Signed',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: pendingCount > 0 ? const Color(0xFFD97706) : const Color(0xFF10B981),
                  ),
                ),
              ),
              if (pendingCount > 0) ...[
                const SizedBox(width: 8),
                Text(
                  '($pendingCount pending)',
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : const Color(0xFF64748B)),
                ),
              ],
              const Spacer(),
              if (pendingCount > 0)
                ElevatedButton.icon(
                  onPressed: _isRemindingAll ? null : _sendRemindAll,
                  icon: _isRemindingAll
                      ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.mark_email_read_outlined, size: 14, color: Colors.white),
                  label: Text(
                    _isRemindingAll ? 'Sending...' : 'Remind All Pending',
                    style: const TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    minimumSize: const Size(0, 32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    elevation: 0,
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: _acknowledgements.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final a = _acknowledgements[index];
              final isAcked = a['status'] == 'ACKNOWLEDGED';
              final isRemindingThis = _remindingAckId == a['id'];
              final reminderCount = a['reminder_count'] ?? 0;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    Icon(
                      isAcked ? Icons.check_circle_rounded : Icons.pending_rounded,
                      color: isAcked ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  a['user_name'] ?? a['user_email'] ?? 'Employee',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (!isAcked && reminderCount > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    'Reminded ${reminderCount}x',
                                    style: const TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${a['department'] ?? 'General'} · v${a['version_number']}${a['user_email'] != null ? " · ${a['user_email']}" : ""}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (!isAcked) ...[
                      ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (_) => PolicyAcknowledgementDialog(
                              acknowledgement: {
                                ...a,
                                'policy_id': widget.policyId,
                                'policy_title': _policyData?['title'],
                                'version_number': a['version_number'] ?? _policyData?['current_version'] ?? '1.0',
                              },
                              onAcknowledged: () {
                                _fetchDetails();
                                widget.onPolicyUpdated();
                              },
                            ),
                          );
                        },
                        icon: const Icon(Icons.verified_user_outlined, size: 13, color: Colors.white),
                        label: const Text('Sign Off', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          minimumSize: const Size(0, 30),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: (isRemindingThis || _isRemindingAll) ? null : () => _sendReminder(a['id']),
                        icon: isRemindingThis
                            ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.notifications_active_outlined, size: 14),
                        label: Text(isRemindingThis ? 'Sending...' : 'Remind', style: const TextStyle(fontSize: 11)),
                      ),
                    ]
                    else
                      Text(
                        a['acknowledged_at'] != null ? _dateFormat.format(DateTime.parse(a['acknowledged_at'])) : 'Signed',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActivityTab(bool isDark) {
    if (_activity.isEmpty) {
      return const Center(child: Text('No activity logged.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: _activity.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final act = _activity[index];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.history_rounded, size: 14, color: Color(0xFF4F46E5)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(act['summary'] ?? act['action'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  const SizedBox(height: 2),
                  Text(
                    '${act['performer_name'] ?? 'System'} · ${act['created_at'] != null ? _dateFormat.format(DateTime.parse(act['created_at'])) : ''}',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
