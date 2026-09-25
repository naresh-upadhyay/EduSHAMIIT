import 'package:flutter/material.dart';
import 'package:edu_shamiit_core/services/api_service.dart';

class RecordAssessmentResultDialog extends StatefulWidget {
  final String assessmentId;
  final String assessmentTitle;
  final String candidateName;
  final double? currentScore;
  final double maxScore;
  final String currentResult;
  final String? currentRemarks;
  final VoidCallback onResultUpdated;

  const RecordAssessmentResultDialog({
    super.key,
    required this.assessmentId,
    required this.assessmentTitle,
    required this.candidateName,
    this.currentScore,
    required this.maxScore,
    required this.currentResult,
    this.currentRemarks,
    required this.onResultUpdated,
  });

  @override
  State<RecordAssessmentResultDialog> createState() => _RecordAssessmentResultDialogState();
}

class _RecordAssessmentResultDialogState extends State<RecordAssessmentResultDialog> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  late TextEditingController _scoreController;
  late TextEditingController _maxScoreController;
  late TextEditingController _remarksController;

  late String _result;
  bool _sendEmail = true;
  bool _isSubmitting = false;

  final List<String> _resultOptions = ['Passed', 'Failed', 'Pending'];

  @override
  void initState() {
    super.initState();
    _scoreController = TextEditingController(
      text: widget.currentScore != null ? widget.currentScore.toString() : '',
    );
    _maxScoreController = TextEditingController(text: widget.maxScore.toString());
    _remarksController = TextEditingController(text: widget.currentRemarks ?? '');
    _result = _resultOptions.contains(widget.currentResult) ? widget.currentResult : 'Passed';
  }

  @override
  void dispose() {
    _scoreController.dispose();
    _maxScoreController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _submitResult() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final score = double.tryParse(_scoreController.text.trim());
      final maxScore = double.tryParse(_maxScoreController.text.trim()) ?? widget.maxScore;

      final payload = {
        'score': score,
        'max_score': maxScore,
        'result': _result,
        'remarks': _remarksController.text.trim().isEmpty ? null : _remarksController.text.trim(),
        'send_email': _sendEmail,
      };

      await _apiService.put('/recruitment/assessments/${widget.assessmentId}/result', payload);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _sendEmail && (_result == 'Passed' || _result == 'Failed')
                  ? 'Assessment result recorded and outcome email sent to ${widget.candidateName}!'
                  : 'Assessment result saved successfully!',
            ),
            backgroundColor: _result == 'Passed'
                ? const Color(0xFF10B981)
                : (_result == 'Failed' ? const Color(0xFFEF4444) : const Color(0xFFF59E0B)),
          ),
        );
        widget.onResultUpdated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error recording result: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color resultColor;
    if (_result == 'Passed') {
      resultColor = const Color(0xFF10B981);
    } else if (_result == 'Failed') {
      resultColor = const Color(0xFFEF4444);
    } else {
      resultColor = const Color(0xFFF59E0B);
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 560,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: resultColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.grading_rounded, color: resultColor, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Record Assessment Outcome',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${widget.candidateName} • ${widget.assessmentTitle}',
                          style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Outcome Selector
              const Text('Evaluation Status / Outcome *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              Row(
                children: _resultOptions.map((opt) {
                  final isSelected = _result == opt;
                  Color optColor;
                  IconData optIcon;
                  if (opt == 'Passed') {
                    optColor = const Color(0xFF10B981);
                    optIcon = Icons.check_circle_rounded;
                  } else if (opt == 'Failed') {
                    optColor = const Color(0xFFEF4444);
                    optIcon = Icons.cancel_rounded;
                  } else {
                    optColor = const Color(0xFFF59E0B);
                    optIcon = Icons.hourglass_top_rounded;
                  }

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: InkWell(
                        onTap: () => setState(() => _result = opt),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? optColor.withValues(alpha: 0.15) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? optColor : Colors.grey.withValues(alpha: 0.3),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(optIcon, size: 16, color: isSelected ? optColor : Colors.grey),
                              const SizedBox(width: 6),
                              Text(
                                opt,
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  color: isSelected ? optColor : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Score achieved and Max score
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _scoreController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Score Achieved',
                        hintText: 'e.g. 88.5',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.score_rounded),
                      ),
                      validator: (v) {
                        if (v != null && v.trim().isNotEmpty) {
                          final num = double.tryParse(v.trim());
                          if (num == null) return 'Enter a valid number';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextFormField(
                      controller: _maxScoreController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Max Score',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.pin_rounded),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Evaluator Feedback & Remarks
              TextFormField(
                controller: _remarksController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Evaluator Remarks / Strengths & Areas of Improvement',
                  hintText: 'Provide detailed qualitative feedback...',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),

              // Email Outcome Notification Card
              Material(
                color: _sendEmail ? resultColor.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.08),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                  side: BorderSide(
                    color: _sendEmail ? resultColor.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.3),
                  ),
                ),
                child: SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  title: const Text(
                    'Email Evaluation Outcome to Candidate',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  subtitle: Text(
                    'Candidate will receive an email notifying them of their assessment status and score.',
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                  ),
                  value: _sendEmail,
                  activeTrackColor: resultColor,
                  onChanged: (val) => setState(() => _sendEmail = val),
                ),
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitResult,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded, size: 16),
                    label: Text(_isSubmitting ? 'Saving...' : 'Save & Publish Result'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: resultColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
