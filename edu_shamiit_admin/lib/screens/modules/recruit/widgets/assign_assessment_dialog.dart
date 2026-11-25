import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:edu_shamiit_core/services/api_service.dart';
import 'package:edu_shamiit_admin/services/hr_lookup_helper.dart';

class AssignAssessmentDialog extends StatefulWidget {
  final String applicationId;
  final String candidateName;
  final String jobTitle;
  final VoidCallback onAssessmentAssigned;

  const AssignAssessmentDialog({
    super.key,
    required this.applicationId,
    required this.candidateName,
    required this.jobTitle,
    required this.onAssessmentAssigned,
  });

  @override
  State<AssignAssessmentDialog> createState() => _AssignAssessmentDialogState();
}

class _AssignAssessmentDialogState extends State<AssignAssessmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _maxScoreController = TextEditingController(text: '100');
  final TextEditingController _testLinkController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();

  String _assessmentType = 'Teaching Demo';
  DateTime _assessmentDate = DateTime.now().add(const Duration(days: 3));
  bool _sendEmail = true;
  bool _isSubmitting = false;

  List<String> _assessmentTypes = HRLookupHelper.instance.getCachedLabels('ASSESSMENT_TYPE');

  @override
  void initState() {
    super.initState();
    HRLookupHelper.instance.addListener(_onLookupsChanged);
    _loadLookups(true);
    _titleController.text = '${widget.jobTitle} - Teaching Demo & Skill Evaluation';
    _instructionsController.text =
        'Please prepare a 20-minute lecture demonstration on your core subject specialization. Presentation materials or whiteboard exercises are welcome.';
  }

  void _onLookupsChanged() {
    if (mounted) {
      _loadLookups(true);
    }
  }

  Future<void> _loadLookups([bool forceRefresh = true]) async {
    final types = await HRLookupHelper.instance.getLookupLabels('ASSESSMENT_TYPE', forceRefresh: forceRefresh);
    if (mounted) {
      setState(() {
        _assessmentTypes = types;
        if (!_assessmentTypes.contains(_assessmentType) && _assessmentTypes.isNotEmpty) {
          _assessmentType = _assessmentTypes.first;
        }
      });
    }
  }

  @override
  void dispose() {
    HRLookupHelper.instance.removeListener(_onLookupsChanged);
    _titleController.dispose();
    _maxScoreController.dispose();
    _testLinkController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _assessmentDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (picked != null) {
      setState(() => _assessmentDate = picked);
    }
  }

  Future<void> _submitAssessment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final maxScore = double.tryParse(_maxScoreController.text.trim()) ?? 100.0;
      final payload = {
        'application_id': widget.applicationId,
        'title': _titleController.text.trim(),
        'assessment_type': _assessmentType,
        'max_score': maxScore,
        'assessment_date': DateFormat('yyyy-MM-dd').format(_assessmentDate),
        'result': 'Pending',
        'test_link': _testLinkController.text.trim().isEmpty ? null : _testLinkController.text.trim(),
        'instructions': _instructionsController.text.trim().isEmpty ? null : _instructionsController.text.trim(),
        'send_email': _sendEmail,
      };

      await _apiService.post('/recruitment/assessments', payload);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _sendEmail
                  ? 'Assessment assigned and email notification dispatched to ${widget.candidateName}!'
                  : 'Assessment recorded successfully!',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        widget.onAssessmentAssigned();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error assigning assessment: $e'),
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

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
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
                      color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.assignment_turned_in_rounded, color: Color(0xFF6366F1), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Assign Candidate Assessment',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${widget.candidateName} • ${widget.jobTitle}',
                          style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
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

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Assessment Title
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Assessment Title *',
                          hintText: 'e.g. Technical Coding Test / Teaching Demo',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.title_rounded),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
                      ),
                      const SizedBox(height: 16),

                      // Type & Max Score Row
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: AppSearchableDropdownFormField<String>.fromMenuItems(
                              initialValue: _assessmentTypes.contains(_assessmentType) ? _assessmentType : (_assessmentTypes.isNotEmpty ? _assessmentTypes.first : null),
                              decoration: const InputDecoration(
                                labelText: 'Assessment Type',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.category_rounded),
                              ),
                              items: _assessmentTypes.map((t) {
                                return DropdownMenuItem(value: t, child: Text(t));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _assessmentType = val;
                                    if (val == 'Teaching Demo') {
                                      _instructionsController.text =
                                          'Please prepare a 20-minute lecture demonstration on your core subject specialization. Presentation materials or whiteboard exercises are welcome.';
                                    } else if (val == 'Technical Test') {
                                      _instructionsController.text =
                                          'Complete the assigned practical problem within the stipulated duration. Ensure your code is thoroughly documented and submitted via the portal link.';
                                    } else if (val == 'Written Test') {
                                      _instructionsController.text =
                                          'Written subject competency test covering core curriculum, pedagogical practices, and educational methodologies.';
                                    }
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _maxScoreController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Max Marks',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.grade_rounded),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Required';
                                if (double.tryParse(v.trim()) == null) return 'Invalid';
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Assessment Date / Due Date
                      InkWell(
                        onTap: _selectDate,
                        borderRadius: BorderRadius.circular(8),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Assessment Due Date',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_month_rounded),
                          ),
                          child: Text(
                            DateFormat('EEEE, dd MMMM yyyy').format(_assessmentDate),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Test Link / Portal URL
                      TextFormField(
                        controller: _testLinkController,
                        decoration: const InputDecoration(
                          labelText: 'Online Portal / Test URL (Optional)',
                          hintText: 'https://assessments.edushamiit.com/test-id',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.link_rounded),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Instructions / Guidelines
                      TextFormField(
                        controller: _instructionsController,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Candidate Instructions & Guidelines',
                          hintText: 'Provide guidance or preparation notes for the candidate...',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Send Email Switch Card
                      Material(
                        color: _sendEmail
                            ? const Color(0xFF6366F1).withValues(alpha: 0.08)
                            : Colors.grey.withValues(alpha: 0.08),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: _sendEmail
                                ? const Color(0xFF6366F1).withValues(alpha: 0.3)
                                : Colors.grey.withValues(alpha: 0.3),
                          ),
                        ),
                        child: SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          title: const Text(
                            'Dispatch Invitation Email to Candidate',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          subtitle: Text(
                            'Candidate will receive an official branded email with instructions and assessment link.',
                            style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                          ),
                          value: _sendEmail,
                          activeTrackColor: const Color(0xFF6366F1),
                          onChanged: (val) => setState(() => _sendEmail = val),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submitAssessment,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded, size: 16),
                    label: Text(_isSubmitting ? 'Assigning...' : 'Assign Assessment'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
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
