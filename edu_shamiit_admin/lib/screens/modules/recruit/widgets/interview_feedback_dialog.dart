import 'package:flutter/material.dart';
import 'package:edu_shamiit_core/services/api_service.dart';

class InterviewFeedbackDialog extends StatefulWidget {
  final String interviewId;
  final String roundTitle;
  final String candidateName;
  final VoidCallback onFeedbackSubmitted;

  const InterviewFeedbackDialog({
    super.key,
    required this.interviewId,
    required this.roundTitle,
    required this.candidateName,
    required this.onFeedbackSubmitted,
  });

  @override
  State<InterviewFeedbackDialog> createState() => _InterviewFeedbackDialogState();
}

class _InterviewFeedbackDialogState extends State<InterviewFeedbackDialog> {
  final ApiService _apiService = ApiService();

  int _technicalSkills = 4;
  int _communication = 4;
  int _subjectKnowledge = 4;
  int _teachingAbility = 4;
  int _problemSolving = 4;
  int _classroomManagement = 4;
  int _leadership = 3;

  String _recommendation = 'Hire';
  final TextEditingController _commentsController = TextEditingController();
  bool _isSubmitting = false;

  final List<String> _recommendations = ['Strong Hire', 'Hire', 'Maybe', 'No Hire'];

  @override
  void dispose() {
    _commentsController.dispose();
    super.dispose();
  }

  double get _averageRating => (
    _technicalSkills +
    _communication +
    _subjectKnowledge +
    _teachingAbility +
    _problemSolving +
    _classroomManagement +
    _leadership
  ) / 7.0;

  Future<void> _submitFeedback() async {
    setState(() => _isSubmitting = true);
    try {
      final payload = {
        'technical_skills': _technicalSkills,
        'communication': _communication,
        'subject_knowledge': _subjectKnowledge,
        'teaching_ability': _teachingAbility,
        'problem_solving': _problemSolving,
        'classroom_management': _classroomManagement,
        'leadership': _leadership,
        'recommendation': _recommendation,
        'comments': _commentsController.text.trim().isEmpty ? null : _commentsController.text.trim(),
      };

      await _apiService.post(
        '/recruitment/interviews/${widget.interviewId}/feedback',
        payload,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Interview feedback submitted successfully!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
        widget.onFeedbackSubmitted();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
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

  Widget _buildRatingRow(String label, int value, ValueChanged<int> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w500),
            ),
          ),
          Row(
            children: List.generate(5, (idx) {
              final star = idx + 1;
              return InkWell(
                onTap: () => onChanged(star),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Icon(
                    star <= value ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: star <= value ? const Color(0xFFF59E0B) : const Color(0xFFCBD5E1),
                    size: 22,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 560,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
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
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.rate_review_rounded, color: Color(0xFFD97706), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Submit Interview Feedback',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                        Text(
                          '${widget.candidateName} • ${widget.roundTitle}',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(height: 28),

              // Average Rating Banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Overall Average Score:',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 18),
                        const SizedBox(width: 4),
                        Text(
                          '${_averageRating.toStringAsFixed(1)} / 5.0',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              const Text('Competency Ratings', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 6),
              _buildRatingRow('Technical & Core Competency', _technicalSkills, (v) => setState(() => _technicalSkills = v)),
              _buildRatingRow('Communication & Articulation', _communication, (v) => setState(() => _communication = v)),
              _buildRatingRow('Subject Matter Knowledge', _subjectKnowledge, (v) => setState(() => _subjectKnowledge = v)),
              _buildRatingRow('Teaching / Delivery Ability', _teachingAbility, (v) => setState(() => _teachingAbility = v)),
              _buildRatingRow('Problem Solving & Adaptability', _problemSolving, (v) => setState(() => _problemSolving = v)),
              _buildRatingRow('Classroom Management / Organization', _classroomManagement, (v) => setState(() => _classroomManagement = v)),
              _buildRatingRow('Leadership & Team Alignment', _leadership, (v) => setState(() => _leadership = v)),

              const Divider(height: 24),

              // Final Recommendation
              const Text('Recommendation', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _recommendations.map((rec) {
                  final isSelected = _recommendation == rec;
                  Color activeColor;
                  if (rec == 'Strong Hire') {
                    activeColor = const Color(0xFF059669);
                  } else if (rec == 'Hire') {
                    activeColor = const Color(0xFF10B981);
                  } else if (rec == 'Maybe') {
                    activeColor = const Color(0xFFF59E0B);
                  } else {
                    activeColor = const Color(0xFFEF4444);
                  }

                  return ChoiceChip(
                    label: Text(rec, style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF334155), fontSize: 12, fontWeight: FontWeight.w600)),
                    selected: isSelected,
                    selectedColor: activeColor,
                    backgroundColor: const Color(0xFFF1F5F9),
                    onSelected: (selected) {
                      if (selected) setState(() => _recommendation = rec);
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Comments
              const Text('Detailed Comments & Evaluation Notes', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
              const SizedBox(height: 6),
              TextField(
                controller: _commentsController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Provide specific feedback, strengths, and areas of concern...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 24),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitFeedback,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF059669),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check_circle_outline_rounded, size: 18, color: Colors.white),
                    label: Text(
                      _isSubmitting ? 'Submitting...' : 'Save Feedback',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
