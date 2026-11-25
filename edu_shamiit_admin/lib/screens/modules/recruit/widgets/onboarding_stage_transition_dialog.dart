import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:edu_shamiit_core/services/api_service.dart';

class OnboardingStageTransitionDialog extends StatefulWidget {
  final String onboardingId;
  final String candidateName;
  final String onboardingCode;
  final String designation;
  final String department;
  final String currentStage;
  final VoidCallback onStageChanged;

  const OnboardingStageTransitionDialog({
    super.key,
    required this.onboardingId,
    required this.candidateName,
    required this.onboardingCode,
    required this.designation,
    required this.department,
    required this.currentStage,
    required this.onStageChanged,
  });

  @override
  State<OnboardingStageTransitionDialog> createState() => _OnboardingStageTransitionDialogState();
}

class _OnboardingStageTransitionDialogState extends State<OnboardingStageTransitionDialog> {
  final ApiService _api = ApiService();
  final TextEditingController _notesController = TextEditingController();

  late String _selectedStage;
  bool _notifyCandidate = true;
  bool _isSubmitting = false;

  final List<String> _pipelineStages = [
    'Offer Accepted',
    'Document Collection',
    'Orientation',
    'IT Setup',
    'Training',
    'Completed',
  ];

  final List<String> _allStages = [
    'Offer Accepted',
    'Document Collection',
    'Orientation',
    'IT Setup',
    'Training',
    'Completed',
    'On Hold',
    'Cancelled',
  ];

  final List<String> _quickNotes = [
    'All KYC documents verified',
    'Orientation session completed',
    'IT assets & email assigned',
    'Department training ongoing',
    'Formalities finalized',
  ];

  @override
  void initState() {
    super.initState();
    // Default selected stage to next stage in pipeline if possible
    final currentIdx = _pipelineStages.indexOf(widget.currentStage);
    if (currentIdx != -1 && currentIdx < _pipelineStages.length - 1) {
      _selectedStage = _pipelineStages[currentIdx + 1];
    } else {
      _selectedStage = widget.currentStage;
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Color _getStageColor(String stage) {
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
      case 'On Hold':
        return const Color(0xFFF97316);
      case 'Cancelled':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF64748B);
    }
  }

  IconData _getStageIcon(String stage) {
    switch (stage) {
      case 'Offer Accepted':
        return Icons.handshake_outlined;
      case 'Document Collection':
        return Icons.description_outlined;
      case 'Orientation':
        return Icons.school_outlined;
      case 'IT Setup':
        return Icons.computer_outlined;
      case 'Training':
        return Icons.model_training_rounded;
      case 'Completed':
        return Icons.verified_outlined;
      case 'On Hold':
        return Icons.pause_circle_outline_rounded;
      case 'Cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.alt_route_rounded;
    }
  }

  Future<void> _submitTransition() async {
    if (_selectedStage == widget.currentStage) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a different stage to transition to.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final res = await _api.patch('/onboarding/records/${widget.onboardingId}/stage', {
        'stage': _selectedStage,
        'notes': _notesController.text.trim(),
        'send_email': _notifyCandidate,
      });

      if (res['success'] == true) {
        if (!mounted) return;
        Navigator.of(context).pop(true);
        widget.onStageChanged();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Stage successfully updated to "$_selectedStage"!'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['detail'] ?? 'Failed to update stage.'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('ApiException: ', '')),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentIdx = _pipelineStages.indexOf(widget.currentStage);

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.published_with_changes_rounded, color: Color(0xFF4F46E5), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Advance Onboarding Stage',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Transition candidate along the onboarding pipeline and track progress.',
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
              const SizedBox(height: 20),

              // Candidate Summary Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: const Color(0xFF4F46E5).withValues(alpha: 0.15),
                      child: Text(
                        widget.candidateName.isNotEmpty ? widget.candidateName[0].toUpperCase() : 'C',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF4F46E5)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.candidateName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${widget.onboardingCode} • ${widget.designation} • ${widget.department}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStageColor(widget.currentStage).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: _getStageColor(widget.currentStage).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_getStageIcon(widget.currentStage), size: 13, color: _getStageColor(widget.currentStage)),
                          const SizedBox(width: 4),
                          Text(
                            widget.currentStage,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _getStageColor(widget.currentStage),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Visual Pipeline Stepper
              Text(
                'Pipeline Progression',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: List.generate(_pipelineStages.length, (idx) {
                    final stage = _pipelineStages[idx];
                    final isCurrent = stage == widget.currentStage;
                    final isSelected = stage == _selectedStage;
                    final isPast = currentIdx != -1 && idx < currentIdx;
                    final stageColor = _getStageColor(stage);

                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: () => setState(() => _selectedStage = stage),
                          borderRadius: BorderRadius.circular(8),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? stageColor.withValues(alpha: 0.15)
                                  : (isCurrent
                                      ? const Color(0xFF4F46E5).withValues(alpha: 0.08)
                                      : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9))),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? stageColor
                                    : (isCurrent ? const Color(0xFF4F46E5) : (isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1))),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isPast ? Icons.check_circle_rounded : _getStageIcon(stage),
                                      size: 14,
                                      color: isPast ? const Color(0xFF10B981) : (isSelected ? stageColor : const Color(0xFF64748B)),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${idx + 1}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? stageColor : const Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  stage,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: isSelected || isCurrent ? FontWeight.bold : FontWeight.w500,
                                    color: isSelected
                                        ? stageColor
                                        : (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (idx < _pipelineStages.length - 1)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Icon(
                              Icons.arrow_forward_rounded,
                              size: 14,
                              color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                            ),
                          ),
                      ],
                    );
                  }),
                ),
              ),
              const SizedBox(height: 20),

              // Target Stage Dropdown
              const Text('Target Stage *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              AppSearchableDropdownFormField<String>.fromMenuItems(
                initialValue: _selectedStage,
                decoration: InputDecoration(
                  prefixIcon: Icon(_getStageIcon(_selectedStage), color: _getStageColor(_selectedStage), size: 18),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                items: _allStages.map((s) {
                  final color = _getStageColor(s);
                  return DropdownMenuItem(
                    value: s,
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Text(s, style: const TextStyle(fontSize: 13)),
                        if (s == widget.currentStage)
                          const Text(' (Current)', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedStage = val);
                },
              ),
              const SizedBox(height: 16),

              // Transition Notes
              const Text('Transition Notes / Remarks (Optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLines: 2,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'e.g. Identity documents verified by HR coordinator; scheduling orientation session.',
                  hintStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 8),

              // Quick Note Tag Chips
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _quickNotes.map((note) {
                  return ActionChip(
                    label: Text(note, style: const TextStyle(fontSize: 11)),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onPressed: () {
                      final current = _notesController.text.trim();
                      if (current.isEmpty) {
                        _notesController.text = note;
                      } else {
                        _notesController.text = '$current. $note';
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),

              // Checkbox: Notify Candidate
              InkWell(
                onTap: () => setState(() => _notifyCandidate = !_notifyCandidate),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _notifyCandidate,
                        activeColor: const Color(0xFF4F46E5),
                        onChanged: (val) => setState(() => _notifyCandidate = val ?? true),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Notify candidate via email', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            Text(
                              'Sends an automated stage update notification email with next steps to candidate.',
                              style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitTransition,
                    icon: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                    label: Text(
                      _selectedStage != widget.currentStage ? 'Transition to $_selectedStage' : 'Confirm Transition',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
