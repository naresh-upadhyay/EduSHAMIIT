import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:edu_shamiit_core/edu_shamiit_core.dart';
import 'schedule_interview_dialog.dart';
import 'assign_assessment_dialog.dart';
import 'record_assessment_result_dialog.dart';
import 'create_offer_dialog.dart';
import 'offer_letter_preview_dialog.dart';
import 'hire_candidate_dialog.dart';
import 'interview_feedback_dialog.dart';
import 'stage_progression_dialog.dart';

class CandidateDetailDrawer extends StatefulWidget {
  final String candidateId;
  final VoidCallback onActionCompleted;
  final VoidCallback? onClose;

  const CandidateDetailDrawer({
    super.key,
    required this.candidateId,
    required this.onActionCompleted,
    this.onClose,
  });

  @override
  State<CandidateDetailDrawer> createState() => _CandidateDetailDrawerState();
}

class _CandidateDetailDrawerState extends State<CandidateDetailDrawer> with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic> _data = {};
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _fetchCandidateDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchCandidateDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _api.get('/recruitment/candidates/${widget.candidateId}', useCache: false);
      if (res['success'] == true) {
        setState(() {
          _data = res['data'] as Map<String, dynamic>? ?? {};
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = res['detail'] ?? 'Failed to load candidate details.';
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

  Future<void> _moveStage(String targetStage, {String? notes, bool notifyCandidate = true}) async {
    final app = _data['current_application'];
    if (app == null) return;
    final appId = app['id'].toString();

    try {
      final res = await _api.post('/recruitment/applications/$appId/move-stage', {
        'to_stage': targetStage,
        'notes': notes ?? 'Moved via Candidate 360 Drawer',
      });
      if (res['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Candidate stage moved to $targetStage'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        _fetchCandidateDetails();
        widget.onActionCompleted();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('ApiException: ', '')), backgroundColor: const Color(0xFFEF4444)),
      );
    }
  }

  void _openStageProgressionDialog() {
    final app = _data['current_application'];
    if (app == null) return;
    showDialog(
      context: context,
      builder: (ctx) => StageProgressionDialog(
        applicationId: app['id'].toString(),
        candidateName: _data['full_name'] ?? '',
        candidateCode: _data['candidate_code'],
        jobTitle: app['job_title'],
        currentStage: app['current_stage'] ?? 'Applied',
        onConfirm: (targetStage, notes, notifyCandidate) async {
          await _moveStage(targetStage, notes: notes, notifyCandidate: notifyCandidate);
        },
      ),
    );
  }

  Future<void> _showRejectDialog() async {
    final app = _data['current_application'];
    if (app == null) return;
    final appId = app['id'].toString();
    final reasonController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: Color(0xFFEF4444)),
            SizedBox(width: 8),
            Text('Reject Application'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Are you sure you want to reject ${_data['full_name'] ?? "this candidate"}?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Rejection Reason (Optional)',
                hintText: 'e.g. Qualifications do not match requirements',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white),
            child: const Text('Confirm Rejection'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        final res = await _api.post('/recruitment/applications/$appId/reject', {
          'reason': reasonController.text.trim().isEmpty ? 'Not specified' : reasonController.text.trim(),
        });
        if (res['success'] == true) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Candidate application marked as Rejected'), backgroundColor: Color(0xFFEF4444)),
          );
          _fetchCandidateDetails();
          widget.onActionCompleted();
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('ApiException: ', '')), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  String _resolveFileUrl(String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return '';
    final trimmed = rawUrl.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return AppConfig.resolveUrl(trimmed);
    }
    final path = trimmed.startsWith('/') ? trimmed : '/$trimmed';
    return AppConfig.resolveUrl('${AppConfig.baseUrl}$path');
  }

  Future<void> _viewInNewTab(String? fileUrl, {String? title}) async {
    final fullUrl = _resolveFileUrl(fileUrl);
    if (fullUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document URL is not available.'), backgroundColor: Color(0xFFEF4444)),
      );
      return;
    }

    try {
      final uri = Uri.parse(fullUrl);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open document: $e'), backgroundColor: const Color(0xFFEF4444)),
      );
    }
  }

  String _generateSafeFilename(String? name, String url) {
    if (name != null && name.trim().isNotEmpty) {
      final clean = name.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      if (clean.contains('.')) return clean;
      final ext = _extractExtension(url);
      return '$clean$ext';
    }
    final uri = Uri.tryParse(url);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      final last = uri.pathSegments.last;
      if (last.contains('.')) return last;
    }
    return 'document.pdf';
  }

  String _extractExtension(String url) {
    final uri = Uri.tryParse(url);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      final last = uri.pathSegments.last;
      final dot = last.lastIndexOf('.');
      if (dot != -1) return last.substring(dot);
    }
    return '.pdf';
  }

  Future<void> _downloadDocument(String? fileUrl, {String? filename}) async {
    final fullUrl = _resolveFileUrl(fileUrl);
    if (fullUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Document URL is not available.'), backgroundColor: Color(0xFFEF4444)),
      );
      return;
    }

    final safeFilename = _generateSafeFilename(filename, fullUrl);

    try {
      final helper = getDownloadHelper();
      await helper.downloadFile(fullUrl, safeFilename);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Downloading $safeFilename...'), backgroundColor: const Color(0xFF10B981)),
      );
    } catch (e) {
      try {
        await launchUrl(Uri.parse(fullUrl), mode: LaunchMode.externalApplication);
      } catch (launchErr) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  Future<void> _addNoteDialog() async {
    final controller = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Internal Recruitment Note'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter internal notes, observations, or action items...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4F46E5)),
            child: const Text('Save Note', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && controller.text.trim().isNotEmpty) {
      try {
        final res = await _api.post('/recruitment/candidates/${widget.candidateId}/notes', {
          'note': controller.text.trim(),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(res['message'] ?? 'Note saved successfully!'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
        _fetchCandidateDetails();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('ApiException: ', '')), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final app = _data['current_application'];
    final currentStage = app?['current_stage'] ?? 'Applied';

    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width > 900 ? 760 : MediaQuery.of(context).size.width * 0.94,
          height: MediaQuery.of(context).size.height,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF13182C) : Colors.white,
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(-5, 0)),
            ],
          ),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))
              : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 40),
                          const SizedBox(height: 12),
                          Text(_errorMessage!, style: const TextStyle(color: Color(0xFFEF4444))),
                          const SizedBox(height: 12),
                          ElevatedButton(onPressed: _fetchCandidateDetails, child: const Text('Retry')),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // Top Header Bar with Close and Candidate Summary
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0B0E1B) : const Color(0xFFF8FAFC),
                            border: Border(bottom: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0))),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 26,
                                          backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                                          child: Text(
                                            (_data['full_name'] ?? 'C')[0].toUpperCase(),
                                            style: const TextStyle(color: Color(0xFF4F46E5), fontSize: 20, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      _data['full_name'] ?? 'Candidate',
                                                      style: TextStyle(
                                                        fontSize: 18,
                                                        fontWeight: FontWeight.bold,
                                                        fontFamily: 'Outfit',
                                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if ((_data['candidate_code'] ?? '').toString().isNotEmpty) ...[
                                                    const SizedBox(width: 10),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                      child: Text(
                                                        _data['candidate_code'] ?? '',
                                                        style: const TextStyle(color: Color(0xFF4F46E5), fontSize: 11, fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${app?['job_title'] ?? 'General Application'} • ${_data['experience_years'] ?? 0} yrs experience',
                                                style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded),
                                    onPressed: () {
                                      if (widget.onClose != null) {
                                        widget.onClose!();
                                      } else {
                                        Navigator.of(context).pop();
                                      }
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Quick Action Buttons Row
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  // Stage Dropdown with Full Pipeline Context
                                  Builder(
                                    builder: (context) {
                                      final stageInfo = RecruitmentPipelineStage.find(currentStage);
                                      final stageStep = stageInfo?.step ?? 1;
                                      final stageColor = stageInfo?.color ?? const Color(0xFF4F46E5);

                                      return PopupMenuButton<String>(
                                        tooltip: 'Recruitment Pipeline Progression',
                                        offset: const Offset(0, 42),
                                        constraints: const BoxConstraints(minWidth: 280, maxWidth: 360),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        onSelected: (target) {
                                          if (target == '__open_stepper__') {
                                            _openStageProgressionDialog();
                                          } else if (target == '__reject__') {
                                            _showRejectDialog();
                                          } else {
                                            _moveStage(target);
                                          }
                                        },
                                        itemBuilder: (ctx) => RecruitmentPipelineStage.buildPipelineMenu(
                                          context: ctx,
                                          currentStage: currentStage,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: stageColor,
                                            borderRadius: BorderRadius.circular(8),
                                            boxShadow: [
                                              BoxShadow(
                                                color: stageColor.withValues(alpha: 0.28),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(stageInfo?.icon ?? Icons.circle, color: Colors.white, size: 15),
                                              const SizedBox(width: 6),
                                              Flexible(
                                                child: Text(
                                                  'Stage: ${stageInfo?.label ?? currentStage} (Step $stageStep/8)',
                                                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              const Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),

                                  // Schedule Interview
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      if (app != null) {
                                        showDialog(
                                          context: context,
                                          builder: (ctx) => ScheduleInterviewDialog(
                                            applicationId: app['id'].toString(),
                                            candidateName: _data['full_name'] ?? '',
                                            jobTitle: app['job_title'] ?? '',
                                            onScheduled: () {
                                              _fetchCandidateDetails();
                                              widget.onActionCompleted();
                                            },
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.calendar_today_rounded, size: 14),
                                    label: const Text('Schedule Interview', style: TextStyle(fontSize: 12)),
                                  ),

                                  // Assign Assessment
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      if (app != null) {
                                        showDialog(
                                          context: context,
                                          builder: (ctx) => AssignAssessmentDialog(
                                            applicationId: app['id'].toString(),
                                            candidateName: _data['full_name'] ?? '',
                                            jobTitle: app['job_title'] ?? '',
                                            onAssessmentAssigned: () {
                                              _fetchCandidateDetails();
                                              widget.onActionCompleted();
                                            },
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.assignment_turned_in_outlined, size: 14, color: Color(0xFF6366F1)),
                                    label: const Text('Assign Assessment', style: TextStyle(fontSize: 12, color: Color(0xFF6366F1))),
                                  ),

                                  // Create Offer
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      if (app != null) {
                                        showDialog(
                                          context: context,
                                          builder: (ctx) => CreateOfferDialog(
                                            applicationId: app['id'].toString(),
                                            candidateName: _data['full_name'] ?? '',
                                            jobTitle: app['job_title'] ?? '',
                                            onOfferCreated: () {
                                              _fetchCandidateDetails();
                                              widget.onActionCompleted();
                                            },
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.local_offer_outlined, size: 14, color: Color(0xFF10B981)),
                                    label: const Text('Create Offer', style: TextStyle(fontSize: 12, color: Color(0xFF10B981))),
                                  ),

                                  // Hire Candidate
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      if (app != null) {
                                        final offers = (_data['offers'] as List<dynamic>?) ?? [];
                                        final acceptedOffer = offers.firstWhere(
                                          (o) => o is Map<String, dynamic> && o['status'] == 'Accepted',
                                          orElse: () => null,
                                        );
                                        final offerJoiningDate = acceptedOffer != null
                                            ? acceptedOffer['joining_date']?.toString()
                                            : null;

                                        showDialog(
                                          context: context,
                                          builder: (ctx) => HireCandidateDialog(
                                            candidateId: widget.candidateId,
                                            applicationId: app['id'].toString(),
                                            candidateName: _data['full_name'] ?? '',
                                            jobTitle: app['job_title'] ?? '',
                                            department: app['department'] ?? 'Teaching',
                                            initialJoiningDate: offerJoiningDate,
                                            onHired: () {
                                              _fetchCandidateDetails();
                                              widget.onActionCompleted();
                                            },
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.check_circle_rounded, size: 14, color: Colors.white),
                                    label: const Text('Hire Candidate', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                                  ),

                                  // Add Note
                                  OutlinedButton.icon(
                                    onPressed: _addNoteDialog,
                                    icon: const Icon(Icons.note_add_outlined, size: 14),
                                    label: const Text('Add Note', style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Tab Header Bar
                        TabBar(
                          controller: _tabController,
                          isScrollable: true,
                          tabAlignment: TabAlignment.start,
                          padding: EdgeInsets.zero,
                          indicatorColor: const Color(0xFF4F46E5),
                          labelColor: const Color(0xFF4F46E5),
                          unselectedLabelColor: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          tabs: const [
                            Tab(text: 'Profile Details'),
                            Tab(text: 'Interviews & Feedback'),
                            Tab(text: 'Assessments'),
                            Tab(text: 'Offers'),
                            Tab(text: 'Documents'),
                            Tab(text: 'Timeline & History'),
                          ],
                        ),

                        // Tab Body Content
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildProfileDetailsTab(isDark),
                              _buildInterviewsTab(isDark),
                              _buildAssessmentsTab(isDark),
                              _buildOffersTab(isDark),
                              _buildDocumentsTab(isDark),
                              _buildTimelineTab(isDark),
                            ],
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _buildProfileDetailsTab(bool isDark) {
    final curApp = _data['current_application'] as Map<String, dynamic>?;

    final rawSpec = _data['specialization'] ?? curApp?['specialization'];
    final spec = (rawSpec != null && rawSpec.toString().trim().isNotEmpty) ? rawSpec.toString() : '-';

    final rawSalary = _data['expected_salary'] ?? curApp?['expected_salary'];
    String salaryStr = '-';
    if (rawSalary != null) {
      final numVal = (rawSalary is num) ? rawSalary : double.tryParse(rawSalary.toString().replaceAll(RegExp(r'[^\d.]'), ''));
      if (numVal != null && numVal > 0) {
        if (numVal == numVal.roundToDouble()) {
          salaryStr = '₹${NumberFormat('#,##,###').format(numVal.toInt())}';
        } else {
          salaryStr = '₹${NumberFormat('#,##,###.##').format(numVal)}';
        }
      }
    }

    final rawNotice = _data['notice_period_days'] ?? curApp?['notice_period_days'];
    final notice = (rawNotice != null && rawNotice.toString().trim().isNotEmpty)
        ? rawNotice.toString()
        : '0';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Email Address', _data['email'] ?? '-'),
          _buildInfoRow('Phone Number', _data['phone'] ?? '-'),
          _buildInfoRow('Gender & DOB', '${_data['gender'] ?? '-'} • ${_data['date_of_birth'] ?? '-'}'),
          _buildInfoRow('Location', '${_data['city'] ?? '-'}, ${_data['state'] ?? '-'}'),
          _buildInfoRow('Highest Qualification', _data['qualification'] ?? '-'),
          _buildInfoRow('Specialization', spec),
          _buildInfoRow('Current Organization', _data['current_organization'] ?? '-'),
          _buildInfoRow('Current Designation', _data['current_designation'] ?? '-'),
          _buildInfoRow('Expected Salary', salaryStr),
          _buildInfoRow('Notice Period', '$notice days'),
          _buildInfoRow('Source', _data['source'] ?? '-'),
          const SizedBox(height: 16),
          const Text('Candidate Skills:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: ((_data['skills'] as List<dynamic>?) ?? []).map((s) {
              return Chip(
                label: Text(s.toString(), style: const TextStyle(fontSize: 11)),
                backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.08),
                side: BorderSide.none,
              );
            }).toList(),
          ),

          // Internal Recruitment Notes Section
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text('Internal Recruitment Notes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${((_data['notes'] as List<dynamic>?) ?? []).length}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: _addNoteDialog,
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Add Note', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (((_data['notes'] as List<dynamic>?) ?? []).isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: const Text(
                'No internal notes yet. Tap "Add Note" to add interview observations or private candidate notes.',
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            )
          else
            ...((_data['notes'] as List<dynamic>?) ?? []).map((n) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.sticky_note_2_outlined, size: 15, color: Color(0xFF4F46E5)),
                              const SizedBox(width: 6),
                              Text(
                                n['author_name'] ?? 'Recruiter',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF4F46E5)),
                              ),
                            ],
                          ),
                          Text(
                            n['created_at']?.toString().split('T')[0] ?? '',
                            style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        n['note'] ?? '',
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildInterviewsTab(bool isDark) {
    final interviews = (_data['interviews'] as List<dynamic>?) ?? [];
    if (interviews.isEmpty) {
      return const Center(child: Text('No interviews scheduled yet.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: interviews.length,
      itemBuilder: (ctx, i) {
        final itw = interviews[i];
        final feedbacks = (itw['feedbacks'] as List<dynamic>?) ?? [];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${itw['interview_round']} (${itw['mode']})',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: itw['status'] == 'Completed' ? const Color(0xFF10B981).withValues(alpha: 0.1) : const Color(0xFF4F46E5).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        itw['status'] ?? 'Scheduled',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: itw['status'] == 'Completed' ? const Color(0xFF10B981) : const Color(0xFF4F46E5),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text('Date: ${itw['scheduled_date']} from ${itw['scheduled_time_start']} to ${itw['scheduled_time_end']}'),
                if (itw['meeting_link_or_location'] != null)
                  Text('Location/Link: ${itw['meeting_link_or_location']}'),
                const SizedBox(height: 12),

                // Feedback list
                if (feedbacks.isNotEmpty) ...[
                  const Text('Interviewer Feedback:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 6),
                  ...feedbacks.map((fb) {
                    return Container(
                      margin: const EdgeInsets.only(top: 6),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0B0E1B) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(fb['interviewer_name'] ?? 'Interviewer', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              Text('Rating: ${fb['overall_rating']}/5.0 • ${fb['recommendation']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF4F46E5))),
                            ],
                          ),
                          if (fb['comments'] != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(fb['comments'], style: const TextStyle(fontSize: 12)),
                            ),
                        ],
                      ),
                    );
                  }),
                ],

                // Action to add feedback
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (c) => InterviewFeedbackDialog(
                          interviewId: itw['id'].toString(),
                          roundTitle: itw['interview_round'] ?? 'Interview',
                          candidateName: _data['full_name'] ?? '',
                          onFeedbackSubmitted: _fetchCandidateDetails,
                        ),
                      );
                    },
                    icon: const Icon(Icons.rate_review_outlined, size: 14),
                    label: const Text('Submit My Feedback', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _sendOfferEmail(String offerId) async {
    try {
      await _api.post('/recruitment/offers/$offerId/send', {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Offer sent to candidate and formal letter email dispatched to ${_data['email'] ?? 'candidate'}!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        _fetchCandidateDetails();
        widget.onActionCompleted();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  Future<void> _acceptOffer(String offerId) async {
    try {
      await _api.post('/recruitment/offers/$offerId/accept', {});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Offer marked as Accepted! Candidate is ready to be officially Hired.'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        _fetchCandidateDetails();
        widget.onActionCompleted();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  Future<void> _rejectOfferDialog(String offerId) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Mark Offer as Declined'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter reason given by the candidate:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'e.g. Pursuing another opportunity...',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(c).pop(false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.of(c).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            child: const Text('Confirm Decline', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _api.post('/recruitment/offers/$offerId/reject', {
          'reason': reasonController.text.trim(),
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Offer marked as declined/rejected.'),
              backgroundColor: Color(0xFF64748B),
            ),
          );
          _fetchCandidateDetails();
          widget.onActionCompleted();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFEF4444)),
          );
        }
      }
    }
  }

  Widget _buildAssessmentsTab(bool isDark) {
    final assessments = (_data['assessments'] as List<dynamic>?) ?? [];
    final apps = (_data['applications'] as List<dynamic>?) ?? [];
    final app = apps.isNotEmpty ? apps[0] : null;

    return Column(
      children: [
        // Action Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.assignment_turned_in_rounded, size: 18, color: Color(0xFF6366F1)),
                  const SizedBox(width: 8),
                  Text(
                    'Evaluations & Tests (${assessments.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  if (app != null) {
                    showDialog(
                      context: context,
                      builder: (ctx) => AssignAssessmentDialog(
                        applicationId: app['id'].toString(),
                        candidateName: _data['full_name'] ?? '',
                        jobTitle: app['job_title'] ?? '',
                        onAssessmentAssigned: () {
                          _fetchCandidateDetails();
                          widget.onActionCompleted();
                        },
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Assign Assessment', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
            ],
          ),
        ),

        // List or Empty
        Expanded(
          child: assessments.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.assignment_outlined, size: 40, color: Color(0xFF6366F1)),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No Assessments Assigned Yet',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Evaluate candidate competency via Teaching Demos, Technical Problem Solving, or Written Tests with automated email invites.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            if (app != null) {
                              showDialog(
                                context: context,
                                builder: (ctx) => AssignAssessmentDialog(
                                  applicationId: app['id'].toString(),
                                  candidateName: _data['full_name'] ?? '',
                                  jobTitle: app['job_title'] ?? '',
                                  onAssessmentAssigned: () {
                                    _fetchCandidateDetails();
                                    widget.onActionCompleted();
                                  },
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.add_task_rounded, size: 16),
                          label: const Text('Assign First Assessment'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF6366F1),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: assessments.length,
                  itemBuilder: (ctx, i) {
                    final ass = assessments[i];
                    final result = ass['result'] ?? 'Pending';
                    final score = ass['score'] != null ? double.tryParse(ass['score'].toString()) : null;
                    final maxScore = double.tryParse(ass['max_score']?.toString() ?? '100') ?? 100.0;
                    final pct = (score != null && maxScore > 0) ? (score / maxScore).clamp(0.0, 1.0) : 0.0;

                    Color resultColor;
                    IconData resultIcon;
                    if (result == 'Passed') {
                      resultColor = const Color(0xFF10B981);
                      resultIcon = Icons.check_circle_rounded;
                    } else if (result == 'Failed') {
                      resultColor = const Color(0xFFEF4444);
                      resultIcon = Icons.cancel_rounded;
                    } else {
                      resultColor = const Color(0xFFF59E0B);
                      resultIcon = Icons.hourglass_top_rounded;
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title & Result Badge
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: resultColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(resultIcon, color: resultColor, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ass['title'] ?? 'Assessment',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              ass['assessment_type'] ?? 'General',
                                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                                            ),
                                          ),
                                          if (ass['assessment_date'] != null) ...[
                                            const SizedBox(width: 8),
                                            Text(
                                              'Due: ${ass['assessment_date']}',
                                              style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: resultColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: resultColor.withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    result.toUpperCase(),
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: resultColor),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Score Progress Bar
                            if (score != null) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Score: $score / $maxScore',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  Text(
                                    '${(pct * 100).toStringAsFixed(1)}%',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: resultColor),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: pct,
                                  backgroundColor: Colors.grey.withValues(alpha: 0.15),
                                  valueColor: AlwaysStoppedAnimation<Color>(resultColor),
                                  minHeight: 6,
                                ),
                              ),
                              const SizedBox(height: 10),
                            ],

                            // Test Link
                            if (ass['test_link'] != null && ass['test_link'].toString().trim().isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.all(8),
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.link_rounded, size: 14, color: Color(0xFF6366F1)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        ass['test_link'],
                                        style: const TextStyle(fontSize: 11, color: Color(0xFF6366F1), decoration: TextDecoration.underline),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Candidate Instructions
                            if (ass['instructions'] != null && ass['instructions'].toString().trim().isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.all(10),
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.info_outline_rounded, size: 14, color: Color(0xFF64748B)),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Guidelines: ${ass['instructions']}',
                                        style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[300] : const Color(0xFF334155)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Remarks
                            if (ass['remarks'] != null && ass['remarks'].toString().trim().isNotEmpty) ...[
                              Text(
                                'Evaluator Feedback: ${ass['remarks']}',
                                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                              ),
                              const SizedBox(height: 8),
                            ],

                            // Action Button
                            Align(
                              alignment: Alignment.centerRight,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (c) => RecordAssessmentResultDialog(
                                      assessmentId: ass['id'].toString(),
                                      assessmentTitle: ass['title'] ?? 'Assessment',
                                      candidateName: _data['full_name'] ?? '',
                                      currentScore: score,
                                      maxScore: maxScore,
                                      currentResult: result,
                                      currentRemarks: ass['remarks'],
                                      onResultUpdated: () {
                                        _fetchCandidateDetails();
                                        widget.onActionCompleted();
                                      },
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.rate_review_outlined, size: 14),
                                label: Text(
                                  score != null ? 'Update Score & Result' : 'Record Score & Result',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildOffersTab(bool isDark) {
    final offers = (_data['offers'] as List<dynamic>?) ?? [];
    final apps = (_data['applications'] as List<dynamic>?) ?? [];
    final app = apps.isNotEmpty ? apps[0] : null;
    final inrFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

    return Column(
      children: [
        // Action Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.local_offer_rounded, size: 18, color: Color(0xFF10B981)),
                  const SizedBox(width: 8),
                  Text(
                    'Employment Offers (${offers.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  if (app != null) {
                    showDialog(
                      context: context,
                      builder: (ctx) => CreateOfferDialog(
                        applicationId: app['id'].toString(),
                        candidateName: _data['full_name'] ?? '',
                        jobTitle: app['job_title'] ?? '',
                        onOfferCreated: () {
                          _fetchCandidateDetails();
                          widget.onActionCompleted();
                        },
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Create New Offer', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
            ],
          ),
        ),

        // List or Empty
        Expanded(
          child: offers.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.local_offer_outlined, size: 40, color: Color(0xFF10B981)),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No Job Offers Created Yet',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Generate a competitive compensation package and dispatch a formal offer letter directly to the candidate.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            if (app != null) {
                              showDialog(
                                context: context,
                                builder: (ctx) => CreateOfferDialog(
                                  applicationId: app['id'].toString(),
                                  candidateName: _data['full_name'] ?? '',
                                  jobTitle: app['job_title'] ?? '',
                                  onOfferCreated: () {
                                    _fetchCandidateDetails();
                                    widget.onActionCompleted();
                                  },
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Draft First Offer'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: offers.length,
                  itemBuilder: (ctx, i) {
                    final off = offers[i];
                    final status = off['status'] ?? 'Draft';
                    final salary = double.tryParse(off['salary']?.toString() ?? '0') ?? 0.0;
                    final annualCtc = salary * 12;

                    Color statusColor;
                    IconData statusIcon;
                    String statusLabel;
                    if (status == 'Accepted') {
                      statusColor = const Color(0xFF10B981);
                      statusIcon = Icons.check_circle_rounded;
                      statusLabel = 'Accepted';
                    } else if (status == 'Sent') {
                      statusColor = const Color(0xFF3B82F6);
                      statusIcon = Icons.mark_email_read_rounded;
                      statusLabel = 'Sent to Candidate';
                    } else if (status == 'Rejected') {
                      statusColor = const Color(0xFFEF4444);
                      statusIcon = Icons.cancel_rounded;
                      statusLabel = 'Declined';
                    } else {
                      statusColor = const Color(0xFFF59E0B);
                      statusIcon = Icons.edit_note_rounded;
                      statusLabel = 'Draft';
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header: Status badge & Title
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(statusIcon, color: statusColor, size: 14),
                                          const SizedBox(width: 4),
                                          Text(
                                            statusLabel.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: statusColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      off['employment_type'] ?? 'Full-time',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                                if (off['created_at'] != null)
                                  Text(
                                    'Created: ${off['created_at'].toString().split('T')[0]}',
                                    style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 14),

                            // Compensation Highlight Box
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Monthly Compensation', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                        const SizedBox(height: 2),
                                        Text(
                                          inrFormat.format(salary),
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(height: 32, width: 1, color: Colors.grey.withValues(alpha: 0.25)),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Annual CTC (Calculated)', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                        const SizedBox(height: 2),
                                        Text(
                                          inrFormat.format(annualCtc),
                                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Details Grid
                            Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      const Icon(Icons.event_available_rounded, size: 15, color: Color(0xFF64748B)),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Expected Joining: ${off['joining_date']}',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Row(
                                    children: [
                                      const Icon(Icons.hourglass_bottom_rounded, size: 15, color: Color(0xFF64748B)),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Probation: ${off['probation_period_months'] ?? 6} Months',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (off['offer_expiry_date'] != null) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.event_busy_rounded, size: 15, color: Color(0xFFEF4444)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Acceptance Deadline: ${off['offer_expiry_date']}',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444), fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 10),

                            // Benefits
                            if (off['benefits'] != null && off['benefits'].toString().trim().isNotEmpty) ...[
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: off['benefits']
                                    .toString()
                                    .split(',')
                                    .map((b) => Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            b.trim(),
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF059669), fontWeight: FontWeight.w500),
                                          ),
                                        ))
                                    .toList(),
                              ),
                              const SizedBox(height: 10),
                            ],

                            // Terms or Notes
                            if (off['notes'] != null && off['notes'].toString().trim().isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Notes: ${off['notes']}',
                                  style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[300] : const Color(0xFF334155)),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],

                            const Divider(height: 1),
                            const SizedBox(height: 12),

                            // Interactive Actions Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (c) => OfferLetterPreviewDialog(
                                        offer: Map<String, dynamic>.from(off),
                                        candidateName: _data['full_name'] ?? '',
                                        candidateEmail: _data['email'] ?? '',
                                        applicationReference: app?['application_reference'],
                                        onOfferUpdated: () {
                                          _fetchCandidateDetails();
                                          widget.onActionCompleted();
                                        },
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.preview_rounded, size: 14),
                                  label: const Text('Preview Offer Letter', style: TextStyle(fontSize: 12)),
                                ),

                                Row(
                                  children: [
                                    if (status == 'Draft') ...[
                                      ElevatedButton.icon(
                                        onPressed: () => _sendOfferEmail(off['id'].toString()),
                                        icon: const Icon(Icons.send_rounded, size: 14),
                                        label: const Text('Send via Email', style: TextStyle(fontSize: 12)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF3B82F6),
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ] else if (status == 'Sent') ...[
                                      OutlinedButton.icon(
                                        onPressed: () => _rejectOfferDialog(off['id'].toString()),
                                        icon: const Icon(Icons.close_rounded, size: 14, color: Color(0xFFEF4444)),
                                        label: const Text('Mark Declined', style: TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
                                      ),
                                      const SizedBox(width: 8),
                                      ElevatedButton.icon(
                                        onPressed: () => _acceptOffer(off['id'].toString()),
                                        icon: const Icon(Icons.check_rounded, size: 14),
                                        label: const Text('Mark Accepted', style: TextStyle(fontSize: 12)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF10B981),
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ] else if (status == 'Accepted') ...[
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          if (app != null) {
                                            showDialog(
                                              context: context,
                                              builder: (ctx) => HireCandidateDialog(
                                                candidateId: widget.candidateId,
                                                applicationId: app['id'].toString(),
                                                candidateName: _data['full_name'] ?? '',
                                                jobTitle: app['job_title'] ?? '',
                                                department: app['department'] ?? 'Teaching',
                                                initialJoiningDate: off['joining_date']?.toString(),
                                                onHired: () {
                                                  _fetchCandidateDetails();
                                                  widget.onActionCompleted();
                                                },
                                              ),
                                            );
                                          }
                                        },
                                        icon: const Icon(Icons.verified_user_rounded, size: 14),
                                        label: const Text('Hire Candidate Now', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF10B981),
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDocumentsTab(bool isDark) {
    final rawDocs = (_data['documents'] as List<dynamic>?) ?? [];
    final resumeUrl = _data['resume_url']?.toString().trim();
    final hasResume = resumeUrl != null && resumeUrl.isNotEmpty;
    final candidateName = _data['full_name']?.toString() ?? 'Candidate';

    // Assemble deduplicated documents list
    final List<Map<String, dynamic>> displayDocs = [];
    final Set<String> seenUrls = {};

    for (final d in rawDocs) {
      if (d is Map<String, dynamic>) {
        final url = (d['file_url'] ?? '').toString().trim();
        final normUrl = url.toLowerCase();
        if (normUrl.isNotEmpty && !seenUrls.contains(normUrl)) {
          seenUrls.add(normUrl);
          displayDocs.add(Map<String, dynamic>.from(d));
        }
      }
    }

    // If candidate has a resume_url not yet represented in documents, add it
    if (hasResume) {
      final normResume = resumeUrl.toLowerCase();
      final hasResumeInDocs = seenUrls.contains(normResume) ||
          displayDocs.any((d) => (d['document_type'] ?? '').toString().toLowerCase() == 'resume');

      if (!hasResumeInDocs) {
        displayDocs.insert(0, {
          'title': 'Resume - $candidateName',
          'document_type': 'Resume',
          'file_url': resumeUrl,
        });
        seenUrls.add(normResume);
      }
    }

    if (displayDocs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open_rounded, size: 48, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
            const SizedBox(height: 12),
            const Text(
              'No documents uploaded for this candidate.',
              style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: displayDocs.length,
      itemBuilder: (ctx, i) {
        final d = displayDocs[i];
        final docUrl = d['file_url']?.toString();
        final docTitle = d['title']?.toString() ?? 'Document';
        final docType = d['document_type']?.toString() ?? 'Document';
        final isResume = docType.toLowerCase() == 'resume' || docTitle.toLowerCase().contains('resume');
        final isPdf = docTitle.toLowerCase().endsWith('.pdf') || (docUrl != null && docUrl.toLowerCase().contains('.pdf')) || isResume;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
          child: ListTile(
            onTap: (docUrl != null && docUrl.isNotEmpty) ? () => _viewInNewTab(docUrl, title: docTitle) : null,
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (isPdf ? const Color(0xFFEF4444) : const Color(0xFF4F46E5)).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isPdf ? Icons.picture_as_pdf_rounded : Icons.description_outlined,
                color: isPdf ? const Color(0xFFEF4444) : const Color(0xFF4F46E5),
              ),
            ),
            title: Text(docTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Text(
              isResume ? 'Candidate Resume' : docType,
              style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (docUrl != null && docUrl.isNotEmpty) ...[
                  IconButton(
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    tooltip: 'View in new tab',
                    onPressed: () => _viewInNewTab(docUrl, title: docTitle),
                  ),
                  IconButton(
                    icon: const Icon(Icons.download_rounded, size: 18),
                    tooltip: 'Download document',
                    onPressed: () => _downloadDocument(docUrl, filename: docTitle.toLowerCase().endsWith('.pdf') ? docTitle : '$docTitle.pdf'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimelineTab(bool isDark) {
    final history = (_data['stage_history'] as List<dynamic>?) ?? [];
    final notes = (_data['notes'] as List<dynamic>?) ?? [];
    final timeline = (_data['timeline'] as List<dynamic>?) ?? [];

    // Combine all events chronologically
    final List<Map<String, dynamic>> combinedEvents = [];

    for (final h in history) {
      final fromStage = h['from_stage']?.toString();
      final toStage = h['to_stage']?.toString() ?? 'Next Stage';
      final stageTitle = (fromStage != null && fromStage.trim().isNotEmpty && fromStage != toStage)
          ? 'Stage: $fromStage → $toStage'
          : 'Stage Advanced: $toStage';

      combinedEvents.add({
        'type': 'stage',
        'title': stageTitle,
        'badge': 'Stage',
        'subtitle': _formatTimelineTimestamp(h['created_at'], h['changed_by_name']?.toString()),
        'content': h['notes'],
        'created_at': h['created_at'],
        'icon': Icons.trending_up_rounded,
        'color': const Color(0xFF4F46E5),
      });
    }

    for (final n in notes) {
      combinedEvents.add({
        'type': 'note',
        'title': 'Internal Note by ${n['author_name'] ?? 'Recruiter'}',
        'badge': 'Note',
        'subtitle': _formatTimelineTimestamp(n['created_at'], null),
        'content': n['note'],
        'created_at': n['created_at'],
        'icon': Icons.sticky_note_2_outlined,
        'color': const Color(0xFFD97706),
      });
    }

    for (final a in timeline) {
      final rawAction = a['action']?.toString() ?? '';
      if (rawAction != 'Note Added' && rawAction.toUpperCase() != 'NOTE_ADDED') { // Avoid duplicating notes
        final description = a['description']?.toString() ?? '';
        final entity = a['entity']?.toString();
        final title = _formatActionTitle(rawAction, description, entity);
        final icon = _getActionIcon(rawAction, description);
        final color = _getActionColor(rawAction, description);
        final badge = _getActionBadge(rawAction, entity);

        combinedEvents.add({
          'type': 'activity',
          'title': title,
          'badge': badge,
          'subtitle': _formatTimelineTimestamp(a['created_at'], a['user_name']?.toString()),
          'content': description,
          'created_at': a['created_at'],
          'icon': icon,
          'color': color,
        });
      }
    }

    // Sort descending by created_at
    combinedEvents.sort((a, b) {
      final aDate = a['created_at']?.toString() ?? '';
      final bDate = b['created_at']?.toString() ?? '';
      return bDate.compareTo(aDate);
    });

    if (combinedEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_toggle_off_rounded,
              size: 48,
              color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
            ),
            const SizedBox(height: 12),
            Text(
              'No activity recorded yet.',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      itemCount: combinedEvents.length,
      itemBuilder: (ctx, i) {
        final ev = combinedEvents[i];
        final color = ev['color'] as Color;
        final icon = ev['icon'] as IconData;
        final badge = ev['badge']?.toString() ?? '';

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.35), width: 1.5),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            ev['title'] ?? '',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        if (badge.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: color.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              badge,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: color,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 11,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            ev['subtitle'] ?? '',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (ev['content'] != null && ev['content'].toString().trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          ev['content'],
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.45,
                            color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatActionTitle(String? rawAction, String? description, String? entity) {
    if (rawAction == null || rawAction.trim().isEmpty) return 'Activity Recorded';
    final action = rawAction.toUpperCase().trim();
    final desc = (description ?? '').toLowerCase();

    if (action == 'EMAIL_DISPATCHED' || action == 'EMAIL_SENT') {
      if (desc.contains('offer')) {
        return 'Offer Letter Dispatched';
      } else if (desc.contains('assessment outcome') || desc.contains('result')) {
        return 'Assessment Outcome Email Sent';
      } else if (desc.contains('assessment invitation') || desc.contains('invitation') || desc.contains('assessment')) {
        return 'Assessment Invitation Email Sent';
      } else if (desc.contains('interview')) {
        return 'Interview Invitation Email Sent';
      } else if (desc.contains('appointment') || desc.contains('welcome') || desc.contains('hired')) {
        return 'Appointment Welcome Email Sent';
      } else if (desc.contains('rejection') || desc.contains('declined')) {
        return 'Rejection Notice Email Sent';
      }
      return 'Email Notification Dispatched';
    }

    if (action == 'ASSESSMENT_ASSIGNED') {
      return 'Assessment Assigned';
    }

    if (action == 'ASSESSMENT_EVALUATED') {
      if (desc.contains('result: passed') || desc.contains('passed')) {
        return 'Assessment Evaluated • Passed';
      } else if (desc.contains('result: failed') || desc.contains('failed')) {
        return 'Assessment Evaluated • Failed';
      }
      return 'Assessment Evaluation Recorded';
    }

    if (action == 'INTERVIEW_SCHEDULED') {
      return 'Interview Scheduled';
    }

    if (action == 'INTERVIEW_FEEDBACK' || action == 'INTERVIEW_FEEDBACK_SUBMITTED') {
      return 'Interview Feedback Submitted';
    }

    if (action == 'INTERVIEW_COMPLETED') {
      return 'Interview Completed';
    }

    if (action == 'INTERVIEW_RESCHEDULED') {
      return 'Interview Rescheduled';
    }

    if (action == 'INTERVIEW_CANCELLED') {
      return 'Interview Cancelled';
    }

    if (action == 'OFFER_CREATED') {
      return 'Job Offer Generated';
    }

    if (action == 'OFFER_SENT') {
      return 'Job Offer Letter Dispatched';
    }

    if (action == 'OFFER_ACCEPTED') {
      return 'Job Offer Accepted by Candidate';
    }

    if (action == 'OFFER_REJECTED' || action == 'OFFER_DECLINED') {
      return 'Job Offer Declined by Candidate';
    }

    if (action == 'CANDIDATE_HIRED') {
      return 'Candidate Hired Successfully';
    }

    if (action == 'CANDIDATE_CREATED' || action == 'APPLICATION_SUBMITTED') {
      return 'Application Received';
    }

    if (action == 'STAGE_CHANGED' || action == 'STAGE_PROGRESSION') {
      return 'Candidate Stage Advanced';
    }

    if (action == 'CANDIDATE_REJECTED') {
      return 'Application Rejected';
    }

    if (action == 'CANDIDATE_WITHDRAWN') {
      return 'Application Withdrawn';
    }

    if (action == 'NOTE_ADDED') {
      return 'Internal Note Added';
    }

    if (action == 'RESUME_UPLOADED') {
      return 'Resume Document Uploaded';
    }

    if (action == 'DOCUMENT_UPLOADED') {
      return 'Verification Document Uploaded';
    }

    if (action == 'JOB_CREATED') {
      return 'Job Opening Created';
    }

    if (action == 'JOB_UPDATED') {
      return 'Job Opening Updated';
    }

    if (action == 'JOB_DELETED') {
      return 'Job Opening Deleted';
    }

    if (action == 'JOB_PAUSED') {
      return 'Job Opening Paused';
    }

    if (action == 'JOB_ACTIVATED') {
      return 'Job Opening Activated';
    }

    // Generic fallback for any SCREAMING_SNAKE_CASE or snake_case key:
    return rawAction
        .replaceAll('_', ' ')
        .split(' ')
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
        .join(' ');
  }

  IconData _getActionIcon(String? rawAction, String? description) {
    if (rawAction == null) return Icons.history_rounded;
    final action = rawAction.toUpperCase().trim();
    final desc = (description ?? '').toLowerCase();

    if (action.contains('EMAIL')) {
      return Icons.mark_email_read_outlined;
    }
    if (action.contains('ASSESSMENT')) {
      if (action.contains('ASSIGNED')) return Icons.assignment_outlined;
      if (desc.contains('passed')) return Icons.verified_outlined;
      if (desc.contains('failed')) return Icons.highlight_off_rounded;
      return Icons.fact_check_outlined;
    }
    if (action.contains('INTERVIEW')) {
      if (action.contains('FEEDBACK')) return Icons.rate_review_outlined;
      return Icons.calendar_month_rounded;
    }
    if (action.contains('OFFER')) {
      if (action.contains('ACCEPTED')) return Icons.check_circle_outline_rounded;
      if (action.contains('REJECTED') || action.contains('DECLINED')) return Icons.cancel_outlined;
      if (action.contains('SENT')) return Icons.send_rounded;
      return Icons.local_offer_outlined;
    }
    if (action.contains('HIRED')) {
      return Icons.how_to_reg_rounded;
    }
    if (action.contains('STAGE')) {
      return Icons.trending_up_rounded;
    }
    if (action.contains('NOTE')) {
      return Icons.sticky_note_2_outlined;
    }
    if (action.contains('REJECTED')) {
      return Icons.person_off_outlined;
    }
    if (action.contains('WITHDRAWN')) {
      return Icons.undo_rounded;
    }
    if (action.contains('DOCUMENT') || action.contains('RESUME')) {
      return Icons.description_outlined;
    }
    return Icons.history_rounded;
  }

  Color _getActionColor(String? rawAction, String? description) {
    if (rawAction == null) return const Color(0xFF64748B);
    final action = rawAction.toUpperCase().trim();
    final desc = (description ?? '').toLowerCase();

    if (action.contains('EMAIL')) {
      return const Color(0xFF0284C7); // Sky blue
    }
    if (action.contains('ASSESSMENT')) {
      if (action.contains('ASSIGNED')) return const Color(0xFFD97706); // Amber
      if (desc.contains('passed')) return const Color(0xFF059669); // Emerald
      if (desc.contains('failed')) return const Color(0xFFE11D48); // Rose
      return const Color(0xFF7C3AED); // Purple
    }
    if (action.contains('INTERVIEW')) {
      if (action.contains('FEEDBACK')) return const Color(0xFF0D9488); // Teal
      return const Color(0xFF8B5CF6); // Violet
    }
    if (action.contains('OFFER')) {
      if (action.contains('ACCEPTED')) return const Color(0xFF16A34A); // Green
      if (action.contains('REJECTED') || action.contains('DECLINED')) return const Color(0xFFDC2626); // Red
      if (action.contains('SENT')) return const Color(0xFF2563EB); // Royal Blue
      return const Color(0xFF059669); // Emerald
    }
    if (action.contains('HIRED')) {
      return const Color(0xFF10B981); // Vibrant Green
    }
    if (action.contains('STAGE')) {
      return const Color(0xFF4F46E5); // Indigo
    }
    if (action.contains('NOTE')) {
      return const Color(0xFFD97706); // Amber
    }
    if (action.contains('REJECTED')) {
      return const Color(0xFFDC2626); // Red
    }
    if (action.contains('WITHDRAWN')) {
      return const Color(0xFF64748B); // Slate
    }
    return const Color(0xFF4F46E5);
  }

  String _getActionBadge(String? rawAction, String? entity) {
    if (entity != null && entity.trim().isNotEmpty && entity.trim() != 'Activity') {
      return entity.trim();
    }
    if (rawAction == null) return 'Activity';
    final action = rawAction.toUpperCase().trim();
    if (action.contains('EMAIL')) return 'Email';
    if (action.contains('ASSESSMENT')) return 'Assessment';
    if (action.contains('INTERVIEW')) return 'Interview';
    if (action.contains('OFFER')) return 'Offer';
    if (action.contains('HIRED') || action.contains('HIRING')) return 'Hiring';
    if (action.contains('STAGE')) return 'Stage';
    if (action.contains('NOTE')) return 'Note';
    if (action.contains('DOCUMENT') || action.contains('RESUME')) return 'Document';
    return 'Activity';
  }

  String _formatTimelineTimestamp(dynamic timestamp, String? userName) {
    String timeStr = '';
    if (timestamp != null) {
      DateTime? dt;
      if (timestamp is DateTime) {
        dt = timestamp;
      } else {
        dt = DateTime.tryParse(timestamp.toString());
      }
      if (dt != null) {
        final local = dt.toLocal();
        final now = DateTime.now();
        final isToday = local.year == now.year && local.month == now.month && local.day == now.day;
        final yesterday = now.subtract(const Duration(days: 1));
        final isYesterday = local.year == yesterday.year && local.month == yesterday.month && local.day == yesterday.day;

        final timeFormatted = DateFormat('hh:mm a').format(local);
        if (isToday) {
          timeStr = 'Today at $timeFormatted';
        } else if (isYesterday) {
          timeStr = 'Yesterday at $timeFormatted';
        } else {
          timeStr = '${DateFormat('dd MMM yyyy').format(local)} at $timeFormatted';
        }
      } else {
        timeStr = timestamp.toString().split('T')[0];
      }
    }
    final userPart = (userName != null && userName.trim().isNotEmpty) ? ' • By $userName' : ' • By System';
    return '$timeStr$userPart';
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
