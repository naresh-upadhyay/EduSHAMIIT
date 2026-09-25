import 'package:flutter/material.dart';

/// Central Domain Model for Recruitment Pipeline Stages
class RecruitmentPipelineStage {
  final String key;
  final String label;
  final int step;
  final IconData icon;
  final Color color;
  final String description;

  const RecruitmentPipelineStage({
    required this.key,
    required this.label,
    required this.step,
    required this.icon,
    required this.color,
    required this.description,
  });

  /// Canonical 8 stages in exact recruitment process order
  static const List<RecruitmentPipelineStage> allStages = [
    RecruitmentPipelineStage(
      key: 'Applied',
      label: 'Applied',
      step: 1,
      icon: Icons.contact_page_outlined,
      color: Color(0xFF0284C7),
      description: 'Application submitted and received',
    ),
    RecruitmentPipelineStage(
      key: 'Screening',
      label: 'Screening',
      step: 2,
      icon: Icons.filter_alt_outlined,
      color: Color(0xFFF59E0B),
      description: 'Resume review & preliminary check',
    ),
    RecruitmentPipelineStage(
      key: 'Shortlisted',
      label: 'Shortlisted',
      step: 3,
      icon: Icons.assignment_turned_in_outlined,
      color: Color(0xFF0D9488),
      description: 'Qualified for evaluation & testing',
    ),
    RecruitmentPipelineStage(
      key: 'Assessment',
      label: 'Assessment',
      step: 4,
      icon: Icons.quiz_outlined,
      color: Color(0xFF10B981),
      description: 'Technical, domain & behavioral tests',
    ),
    RecruitmentPipelineStage(
      key: 'Interview',
      label: 'Interview',
      step: 5,
      icon: Icons.forum_outlined,
      color: Color(0xFFEC4899),
      description: 'Panel, technical & managerial rounds',
    ),
    RecruitmentPipelineStage(
      key: 'Selected',
      label: 'Selected Candidates',
      step: 6,
      icon: Icons.verified_outlined,
      color: Color(0xFF6366F1),
      description: 'Approved finalists chosen for hiring',
    ),
    RecruitmentPipelineStage(
      key: 'Offer',
      label: 'Offer',
      step: 7,
      icon: Icons.local_offer_outlined,
      color: Color(0xFF8B5CF6),
      description: 'Offer letter drafted, sent & negotiated',
    ),
    RecruitmentPipelineStage(
      key: 'Hired',
      label: 'Hired',
      step: 8,
      icon: Icons.how_to_reg_outlined,
      color: Color(0xFF059669),
      description: 'Offer accepted; transitioned to onboarding',
    ),
  ];

  /// Find stage info by key or label (case-insensitive)
  static RecruitmentPipelineStage? find(String? stageName) {
    if (stageName == null || stageName.trim().isEmpty) return null;
    final normalized = stageName.trim().toLowerCase();
    for (final s in allStages) {
      if (s.key.toLowerCase() == normalized || s.label.toLowerCase() == normalized) {
        return s;
      }
      if (normalized == 'selected candidates' && s.key == 'Selected') {
        return s;
      }
      if (normalized == 'applications' && s.key == 'Applied') {
        return s;
      }
    }
    return null;
  }

  /// Get step number for stage (1 to 8, or 0 if unknown)
  static int getStep(String? stageName) {
    return find(stageName)?.step ?? 0;
  }

  /// Next stage in the pipeline
  static RecruitmentPipelineStage? getNextStage(String? currentStage) {
    final current = find(currentStage);
    if (current == null) return allStages.first;
    final idx = allStages.indexOf(current);
    if (idx >= 0 && idx < allStages.length - 1) {
      return allStages[idx + 1];
    }
    return null;
  }

  /// Previous stage in the pipeline (for rollback)
  static RecruitmentPipelineStage? getPreviousStage(String? currentStage) {
    final current = find(currentStage);
    if (current == null) return null;
    final idx = allStages.indexOf(current);
    if (idx > 0) {
      return allStages[idx - 1];
    }
    return null;
  }

  /// Check if candidate has completed or passed this stage
  static bool isPassed(String stageKey, String? currentStage) {
    final sStep = getStep(stageKey);
    final cStep = getStep(currentStage);
    return cStep > 0 && sStep < cStep;
  }

  /// Check if candidate is currently in this stage
  static bool isCurrent(String stageKey, String? currentStage) {
    final sStep = getStep(stageKey);
    final cStep = getStep(currentStage);
    return cStep > 0 && sStep == cStep;
  }

  /// Builds a luxury, structured, high-context PopupMenuEntry list for stage dropdowns
  static List<PopupMenuEntry<String>> buildPipelineMenu({
    required BuildContext context,
    required String currentStage,
    bool isBulk = false,
    int bulkCount = 0,
    bool includeModalTrigger = true,
    bool includeRejectAction = true,
  }) {
    final currentInfo = find(currentStage);
    final nextInfo = getNextStage(currentStage);
    final prevInfo = getPreviousStage(currentStage);
    final currentStep = currentInfo?.step ?? 1;

    final entries = <PopupMenuEntry<String>>[];

    // 1. HEADER CARD (Current Stage Context & Progress Stepper)
    entries.add(
      PopupMenuItem<String>(
        enabled: false,
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_tree_rounded, size: 14, color: Color(0xFF38BDF8)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isBulk ? 'BULK MOVE ($bulkCount SELECTED)' : 'RECRUITMENT PIPELINE FLOW',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF94A3B8),
                        letterSpacing: 0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (currentInfo?.color ?? const Color(0xFF6366F1)).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: (currentInfo?.color ?? const Color(0xFF6366F1)).withValues(alpha: 0.6),
                      ),
                    ),
                    child: Text(
                      'Step $currentStep of 8',
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      isBulk ? 'From: ${currentInfo?.label ?? currentStage}' : 'Current: ${currentInfo?.label ?? currentStage}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Visual 8-step dots mini progress
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(8, (i) {
                      final stepNum = i + 1;
                      final isStepPassed = stepNum < currentStep;
                      final isStepCurrent = stepNum == currentStep;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        width: isStepCurrent ? 10 : 4,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isStepCurrent
                              ? const Color(0xFF38BDF8)
                              : (isStepPassed ? const Color(0xFF10B981) : const Color(0xFF475569)),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    // 2. PRIMARY NEXT STAGE CARD (ADVANCE)
    if (nextInfo != null) {
      entries.add(
        PopupMenuItem<String>(
          value: nextInfo.key,
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.arrow_forward_rounded, size: 15, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Advance to: ${nextInfo.label}',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF065F46)),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Text(
                        'Next step • Step ${nextInfo.step} of 8',
                        style: const TextStyle(fontSize: 9.5, color: Color(0xFF047857), fontWeight: FontWeight.w500),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'NEXT',
                    style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 3. PREVIOUS STAGE CARD (ROLLBACK)
    if (prevInfo != null) {
      entries.add(
        PopupMenuItem<String>(
          value: prevInfo.key,
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(Icons.arrow_back_rounded, size: 15, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Rollback to: ${prevInfo.label}',
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF92400E)),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      Text(
                        'Return to previous • Step ${prevInfo.step} of 8',
                        style: const TextStyle(fontSize: 9.5, color: Color(0xFFB45309)),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'PREVIOUS',
                    style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: Color(0xFFB45309)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 4. SECTION DIVIDER: ALL PIPELINE STAGES
    entries.add(
      const PopupMenuItem<String>(
        enabled: false,
        height: 28,
        padding: EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            Expanded(child: Divider(height: 1, color: Color(0xFFE2E8F0))),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'ALL PIPELINE STAGES (1 – 8)',
                style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF94A3B8), letterSpacing: 0.5),
              ),
            ),
            Expanded(child: Divider(height: 1, color: Color(0xFFE2E8F0))),
          ],
        ),
      ),
    );

    // 5. ALL 8 STAGES IN EXACT CHRONOLOGICAL ORDER
    for (final s in allStages) {
      final isCur = isCurrent(s.key, currentStage);
      final isPsd = isPassed(s.key, currentStage);

      entries.add(
        PopupMenuItem<String>(
          value: s.key,
          enabled: !isCur,
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              // Step number circle
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCur
                      ? const Color(0xFF4F46E5)
                      : (isPsd ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFFF1F5F9)),
                  border: Border.all(
                    color: isCur
                        ? const Color(0xFF4F46E5)
                        : (isPsd ? const Color(0xFF10B981) : const Color(0xFFCBD5E1)),
                    width: isCur ? 1.5 : 1,
                  ),
                ),
                child: Center(
                  child: isPsd
                      ? const Icon(Icons.check, size: 12, color: Color(0xFF10B981))
                      : Text(
                          '${s.step}',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: isCur ? Colors.white : const Color(0xFF64748B),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(s.icon, size: 15, color: isCur ? const Color(0xFF4F46E5) : s.color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isCur ? FontWeight.w800 : FontWeight.w600,
                    color: isCur
                        ? const Color(0xFF4F46E5)
                        : (isPsd ? const Color(0xFF475569) : const Color(0xFF1E293B)),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 6),
              if (isCur)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 11, color: Color(0xFF4F46E5)),
                      SizedBox(width: 3),
                      Text(
                        'CURRENT',
                        style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: Color(0xFF4F46E5)),
                      ),
                    ],
                  ),
                )
              else if (isPsd)
                const Text(
                  'Passed',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
                )
              else
                Text(
                  'Step ${s.step}',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)),
                ),
            ],
          ),
        ),
      );
    }

    // 6. TERMINAL / ADVANCED ACTIONS
    if (includeModalTrigger || includeRejectAction) {
      entries.add(
        const PopupMenuItem<String>(
          enabled: false,
          height: 24,
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Divider(height: 1, color: Color(0xFFE2E8F0)),
        ),
      );

      if (includeModalTrigger) {
        entries.add(
          const PopupMenuItem<String>(
            value: '__open_stepper__',
            height: 36,
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(Icons.tune_rounded, size: 16, color: Color(0xFF4F46E5)),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Interactive Pipeline Stepper...',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)),
                  ),
                ),
                Icon(Icons.open_in_new_rounded, size: 13, color: Color(0xFF4F46E5)),
              ],
            ),
          ),
        );
      }

      if (includeRejectAction) {
        entries.add(
          const PopupMenuItem<String>(
            value: '__reject__',
            height: 36,
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Icon(Icons.cancel_outlined, size: 16, color: Color(0xFFEF4444)),
                SizedBox(width: 10),
                Text(
                  'Reject Application',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFFEF4444)),
                ),
              ],
            ),
          ),
        );
      }
    }

    return entries;
  }
}

/// A dedicated, premium modal dialog for candidate stage progression with full visual pipeline stepper
class StageProgressionDialog extends StatefulWidget {
  final String applicationId;
  final String candidateName;
  final String? candidateCode;
  final String? jobTitle;
  final String currentStage;
  final Future<void> Function(String targetStage, String? notes, bool notifyCandidate) onConfirm;

  const StageProgressionDialog({
    super.key,
    required this.applicationId,
    required this.candidateName,
    this.candidateCode,
    this.jobTitle,
    required this.currentStage,
    required this.onConfirm,
  });

  @override
  State<StageProgressionDialog> createState() => _StageProgressionDialogState();
}

class _StageProgressionDialogState extends State<StageProgressionDialog> {
  late String _selectedStage;
  final _notesController = TextEditingController();
  bool _notifyCandidate = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final next = RecruitmentPipelineStage.getNextStage(widget.currentStage);
    _selectedStage = next?.key ?? widget.currentStage;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_selectedStage == widget.currentStage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose a different target stage.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await widget.onConfirm(
        _selectedStage,
        _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        _notifyCandidate,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentInfo = RecruitmentPipelineStage.find(widget.currentStage);
    final selectedInfo = RecruitmentPipelineStage.find(_selectedStage);
    final nextInfo = RecruitmentPipelineStage.getNextStage(widget.currentStage);
    final prevInfo = RecruitmentPipelineStage.getPreviousStage(widget.currentStage);

    final isAdvance = (selectedInfo?.step ?? 0) > (currentInfo?.step ?? 0);
    final isRollback = (selectedInfo?.step ?? 0) < (currentInfo?.step ?? 0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        width: 680,
        constraints: const BoxConstraints(maxHeight: 760),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Modal Top Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_tree_rounded, size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Recruitment Pipeline Progression',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.candidateName} ${widget.candidateCode != null ? "• ${widget.candidateCode}" : ""} • ${widget.jobTitle ?? "General Application"}',
                          style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Modal Body
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  // Current vs Selected Status Comparison Banner
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        // Current Stage
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CURRENT STAGE',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(currentInfo?.icon ?? Icons.circle, size: 16, color: currentInfo?.color ?? const Color(0xFF6366F1)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      currentInfo?.label ?? widget.currentStage,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (currentInfo?.color ?? const Color(0xFF6366F1)).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Step ${currentInfo?.step ?? 0}/8',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: currentInfo?.color ?? const Color(0xFF6366F1)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Arrow
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(
                            isRollback ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded,
                            color: isAdvance ? const Color(0xFF10B981) : (isRollback ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8)),
                            size: 22,
                          ),
                        ),

                        // Target Stage
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isAdvance ? 'TARGET STAGE (ADVANCE)' : (isRollback ? 'TARGET STAGE (ROLLBACK)' : 'TARGET STAGE'),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: isAdvance ? const Color(0xFF059669) : (isRollback ? const Color(0xFFD97706) : const Color(0xFF64748B)),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(selectedInfo?.icon ?? Icons.circle, size: 16, color: selectedInfo?.color ?? const Color(0xFF6366F1)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      selectedInfo?.label ?? _selectedStage,
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (selectedInfo?.color ?? const Color(0xFF6366F1)).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Step ${selectedInfo?.step ?? 0}/8',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: selectedInfo?.color ?? const Color(0xFF6366F1)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Quick Action Buttons (Advance vs Rollback)
                  Row(
                    children: [
                      if (nextInfo != null)
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _selectedStage = nextInfo.key),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _selectedStage == nextInfo.key ? const Color(0xFFECFDF5) : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _selectedStage == nextInfo.key ? const Color(0xFF10B981) : const Color(0xFFE2E8F0),
                                  width: _selectedStage == nextInfo.key ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.arrow_forward_rounded, color: Color(0xFF10B981), size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Next Recommended Step', style: TextStyle(fontSize: 10, color: Color(0xFF059669), fontWeight: FontWeight.w700)),
                                        Text(nextInfo.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      if (nextInfo != null && prevInfo != null) const SizedBox(width: 12),
                      if (prevInfo != null)
                        Expanded(
                          child: InkWell(
                            onTap: () => setState(() => _selectedStage = prevInfo.key),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: _selectedStage == prevInfo.key ? const Color(0xFFFFFBEB) : Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: _selectedStage == prevInfo.key ? const Color(0xFFF59E0B) : const Color(0xFFE2E8F0),
                                  width: _selectedStage == prevInfo.key ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.arrow_back_rounded, color: Color(0xFFF59E0B), size: 18),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Rollback to Previous', style: TextStyle(fontSize: 10, color: Color(0xFFD97706), fontWeight: FontWeight.w700)),
                                        Text(prevInfo.label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // All 8 Pipeline Stages Interactive Stepper
                  const Text(
                    'SELECT TARGET PIPELINE STAGE',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 10),

                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: RecruitmentPipelineStage.allStages.map((stage) {
                      final isSelected = _selectedStage == stage.key;
                      final isCur = RecruitmentPipelineStage.isCurrent(stage.key, widget.currentStage);
                      final isPsd = RecruitmentPipelineStage.isPassed(stage.key, widget.currentStage);

                      Color bg = Colors.white;
                      Color borderCol = const Color(0xFFE2E8F0);
                      if (isSelected) {
                        bg = stage.color.withValues(alpha: 0.1);
                        borderCol = stage.color;
                      } else if (isCur) {
                        bg = const Color(0xFFF1F5F9);
                        borderCol = const Color(0xFF94A3B8);
                      }

                      return InkWell(
                        onTap: () => setState(() => _selectedStage = stage.key),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 148,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderCol, width: isSelected ? 2 : 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isCur ? const Color(0xFF4F46E5) : (isPsd ? const Color(0xFF10B981) : const Color(0xFFE2E8F0)),
                                    ),
                                    child: Center(
                                      child: isPsd
                                          ? const Icon(Icons.check, size: 11, color: Colors.white)
                                          : Text(
                                              '${stage.step}',
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: isCur ? Colors.white : const Color(0xFF475569),
                                              ),
                                            ),
                                    ),
                                  ),
                                  const Spacer(),
                                  if (isCur)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4F46E5),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text('CURRENT', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white)),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(stage.icon, size: 14, color: stage.color),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      stage.label,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                                        color: const Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // Stage Notes & Optional Transition Reason
                  const Text(
                    'STAGE TRANSITION NOTE & AUDIT LOG',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF64748B), letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Enter reason or feedback for moving candidate to $_selectedStage... (e.g. Cleared technical interview with 4.5/5 rating)',
                      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFCBD5E1))),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Candidate Email Notification Toggle
                  CheckboxListTile(
                    value: _notifyCandidate,
                    onChanged: (v) => setState(() => _notifyCandidate = v ?? true),
                    title: const Text('Send Stage Update Email to Candidate', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    subtitle: const Text('Candidate will receive a branded update notification regarding their application status.', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                ],
              ),
            ),

            // Modal Footer Actions
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: _isSubmitting || _selectedStage == widget.currentStage ? null : _handleSubmit,
                    icon: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Icon(isRollback ? Icons.arrow_back_rounded : Icons.arrow_forward_rounded, size: 16),
                    label: Text(
                      _isSubmitting
                          ? 'Moving Stage...'
                          : (_selectedStage == widget.currentStage ? 'Select a Target Stage' : 'Confirm Move to $_selectedStage'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isRollback ? const Color(0xFFF59E0B) : const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
