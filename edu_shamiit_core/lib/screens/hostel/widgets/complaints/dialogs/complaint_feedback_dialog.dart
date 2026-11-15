import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/hostel_provider.dart';

class ComplaintFeedbackDialog extends ConsumerStatefulWidget {
  final String complaintId;
  final String complaintTitle;
  final int? initialRating;
  final int? initialQuality;
  final int? initialResponseTime;
  final int? initialStaffBehavior;
  final String? initialComment;
  final bool? initialIsSatisfied;

  const ComplaintFeedbackDialog({
    super.key,
    required this.complaintId,
    required this.complaintTitle,
    this.initialRating,
    this.initialQuality,
    this.initialResponseTime,
    this.initialStaffBehavior,
    this.initialComment,
    this.initialIsSatisfied,
  });

  @override
  ConsumerState<ComplaintFeedbackDialog> createState() => _ComplaintFeedbackDialogState();
}

class _ComplaintFeedbackDialogState extends ConsumerState<ComplaintFeedbackDialog> {
  late final TextEditingController _commentController;

  int _qualityRating = 5;
  int _responseTimeRating = 5;
  int _staffBehaviorRating = 5;
  bool _isSatisfied = true;
  bool _isSubmitting = false;
  bool _isExistingFeedback = false;

  double get _averageRating {
    return double.parse(
      ((_qualityRating + _responseTimeRating + _staffBehaviorRating) / 3.0)
          .toStringAsFixed(1),
    );
  }

  String get _ratingLabel {
    final avg = _averageRating;
    if (avg >= 4.5) return 'Excellent';
    if (avg >= 3.5) return 'Very Good';
    if (avg >= 2.5) return 'Good';
    if (avg >= 1.5) return 'Fair';
    return 'Poor';
  }

  @override
  void initState() {
    super.initState();

    final currentDetail = ref.read(hostelProvider).selectedComplaintDetail;
    final existingFeedback = (currentDetail?.complaint.id == widget.complaintId)
        ? currentDetail?.feedback
        : null;

    final hasInitial = widget.initialRating != null ||
        widget.initialComment != null ||
        existingFeedback != null;

    _isExistingFeedback = hasInitial;
    _qualityRating = widget.initialQuality ?? existingFeedback?.resolutionQuality ?? widget.initialRating ?? existingFeedback?.rating ?? 5;
    _responseTimeRating = widget.initialResponseTime ?? existingFeedback?.responseTimeRating ?? widget.initialRating ?? existingFeedback?.rating ?? 5;
    _staffBehaviorRating = widget.initialStaffBehavior ?? existingFeedback?.staffBehaviorRating ?? widget.initialRating ?? existingFeedback?.rating ?? 5;
    _isSatisfied = widget.initialIsSatisfied ?? existingFeedback?.isSatisfied ?? true;
    _commentController = TextEditingController(
      text: widget.initialComment ?? existingFeedback?.comment ?? '',
    );

    // If opened without existing loaded detail, asynchronously check backend
    if (!hasInitial) {
      _fetchExistingFeedback();
    }
  }

  Future<void> _fetchExistingFeedback() async {
    try {
      final detail = await ref.read(hostelProvider.notifier).complaintService.getComplaintById(widget.complaintId);
      if (detail?.feedback != null && mounted) {
        final f = detail!.feedback!;
        setState(() {
          _isExistingFeedback = true;
          _qualityRating = f.resolutionQuality ?? f.rating;
          _responseTimeRating = f.responseTimeRating ?? f.rating;
          _staffBehaviorRating = f.staffBehaviorRating ?? f.rating;
          _isSatisfied = f.isSatisfied;
          if (_commentController.text.isEmpty && f.comment != null) {
            _commentController.text = f.comment!;
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);

    final computedRating = _averageRating.round().clamp(1, 5);
    final success = await ref.read(hostelProvider.notifier).submitComplaintFeedback(
      widget.complaintId,
      computedRating,
      quality: _qualityRating,
      responseTime: _responseTimeRating,
      staffBehavior: _staffBehaviorRating,
      comment: _commentController.text.trim().isNotEmpty ? _commentController.text.trim() : null,
      isSatisfied: _isSatisfied,
    );

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop();
      }
    }
  }

  Widget _buildStarRow({
    required int rating,
    required ValueChanged<int> onChanged,
    double size = 28,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        return InkWell(
          onTap: () => onChanged(starValue),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Icon(
              starValue <= rating ? Icons.star_rounded : Icons.star_border_rounded,
              color: starValue <= rating ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
              size: size,
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final fieldBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Dialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: borderColor)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.star_rounded, color: Color(0xFFD97706), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isExistingFeedback ? 'Edit Resolution Feedback' : 'Resolution Feedback',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: textPrimary),
                          ),
                          Text(
                            widget.complaintTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: textSecondary,
                    ),
                  ],
                ),
              ),

              // Body
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Resolution Satisfaction & Overall Rating',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary),
                    ),
                    const SizedBox(height: 12),
                    _buildStarRow(
                      rating: _averageRating.round().clamp(1, 5),
                      onChanged: (val) {
                        setState(() {
                          _qualityRating = val;
                          _responseTimeRating = val;
                          _staffBehaviorRating = val;
                        });
                      },
                      size: 34,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$_ratingLabel ',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFFD97706)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '$_averageRating ★ Average',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFB45309)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Satisfaction toggle
                    InkWell(
                      onTap: () => setState(() => _isSatisfied = !_isSatisfied),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: _isSatisfied
                              ? const Color(0xFF10B981).withValues(alpha: 0.12)
                              : const Color(0xFFEF4444).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _isSatisfied
                                ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                : const Color(0xFFEF4444).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isSatisfied ? Icons.thumb_up_rounded : Icons.thumb_down_rounded,
                              size: 16,
                              color: _isSatisfied ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _isSatisfied ? 'Satisfied with resolution' : 'Not satisfied with resolution',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: _isSatisfied ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Aspect ratings
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text('Resolution Quality', style: TextStyle(fontSize: 12, color: textPrimary)),
                              ),
                              _buildStarRow(
                                rating: _qualityRating,
                                onChanged: (val) => setState(() => _qualityRating = val),
                                size: 18,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text('Response Time', style: TextStyle(fontSize: 12, color: textPrimary)),
                              ),
                              _buildStarRow(
                                rating: _responseTimeRating,
                                onChanged: (val) => setState(() => _responseTimeRating = val),
                                size: 18,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text('Staff Courtesy & Behavior', style: TextStyle(fontSize: 12, color: textPrimary)),
                              ),
                              _buildStarRow(
                                rating: _staffBehaviorRating,
                                onChanged: (val) => setState(() => _staffBehaviorRating = val),
                                size: 18,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Comment field
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Comments / Additional Feedback', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: textPrimary)),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _commentController,
                      maxLines: 3,
                      style: TextStyle(fontSize: 12.5, color: textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Share any notes about the repair experience or remaining issues...',
                        hintStyle: TextStyle(fontSize: 12, color: textSecondary),
                        filled: true,
                        fillColor: fieldBg,
                        contentPadding: const EdgeInsets.all(12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: borderColor)),
                      ),
                    ),
                  ],
                ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: borderColor)),
                ),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton(
                      onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textSecondary,
                        side: BorderSide(color: borderColor),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontSize: 13)),
                    ),
                    ElevatedButton.icon(
                      onPressed: _isSubmitting ? null : _submit,
                      icon: _isSubmitting
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.thumb_up_alt_rounded, size: 16, color: Colors.white),
                      label: Text(
                        _isSubmitting
                            ? 'Saving...'
                            : (_isExistingFeedback ? 'Update Feedback' : 'Submit Feedback'),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
