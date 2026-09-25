import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:edu_shamiit_core/services/api_service.dart';
import 'package:edu_shamiit_admin/services/hr_lookup_helper.dart';

class CreateTrainingDialog extends StatefulWidget {
  final VoidCallback onTrainingCreated;
  final Map<String, dynamic>? initialTraining;

  const CreateTrainingDialog({
    super.key,
    required this.onTrainingCreated,
    this.initialTraining,
  });

  @override
  State<CreateTrainingDialog> createState() => _CreateTrainingDialogState();
}

class _CreateTrainingDialogState extends State<CreateTrainingDialog> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _api = ApiService();

  bool _isSubmitting = false;

  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _trainerNameController = TextEditingController(text: 'Internal HR Trainer');
  final _providerController = TextEditingController(text: 'Greenfield IT Academy');
  final _locationController = TextEditingController(text: 'Digital Lab 1');
  final _durationController = TextEditingController(text: '2');
  final _durationDisplayController = TextEditingController(text: '2 Hours');
  final _capacityController = TextEditingController(text: '30');
  final _budgetController = TextEditingController(text: '15000');
  final _notesController = TextEditingController();

  String _categoryName = 'Digital & Technology';
  String _trainingType = 'Technical';
  bool _isMandatory = false;
  String _trainerType = 'Internal';
  String _targetAudience = 'All Staff';
  String _mode = 'Offline';
  String _assessmentType = 'Quiz';
  bool _hasCertificate = true;
  final String _certValidityType = 'Permanent';
  final int _certValidityMonths = 12;

  DateTime _startDate = DateTime.now().add(const Duration(days: 7));
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  final TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  final TimeOfDay _endTime = const TimeOfDay(hour: 12, minute: 0);

  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  List<String> _categoryOptions = HRLookupHelper.instance.getCachedLabels('TRAINING_CATEGORY');
  List<String> _trainingTypeOptions = HRLookupHelper.instance.getCachedLabels('TRAINING_TYPE');
  List<String> _audienceOptions = ['All Staff', ...HRLookupHelper.instance.getCachedLabels('DEPARTMENT')];
  List<String> _modeOptions = HRLookupHelper.instance.getCachedLabels('TRAINING_MODE');
  List<String> _assessmentOptions = HRLookupHelper.instance.getCachedLabels('TRAINING_ASSESSMENT_TYPE');

  @override
  void initState() {
    super.initState();
    HRLookupHelper.instance.addListener(_onLookupsChanged);
    _loadLookups(true);
    if (widget.initialTraining != null) {
      final t = widget.initialTraining!;
      _titleController.text = t['title'] ?? '';
      _descController.text = t['description'] ?? '';
      _categoryName = t['category_name'] ?? _categoryName;
      _trainingType = t['training_type'] ?? _trainingType;
      _isMandatory = t['is_mandatory'] ?? false;
      _trainerType = t['trainer_type'] ?? 'Internal';
      _trainerNameController.text = t['trainer_name'] ?? '';
      _providerController.text = t['provider_name'] ?? '';
      _targetAudience = t['target_audience'] ?? 'All Staff';
      _mode = t['mode'] ?? 'Offline';
      _locationController.text = t['location_or_link'] ?? '';
      _durationController.text = (t['duration_hours'] ?? 2).toString();
      _durationDisplayController.text = t['duration_display'] ?? '2 Hours';
      _capacityController.text = (t['capacity'] ?? 30).toString();
      _budgetController.text = (t['budget_cost'] ?? 0).toString();
      _notesController.text = t['notes'] ?? '';
      _assessmentType = t['assessment_type'] ?? 'Quiz';
      _hasCertificate = t['has_certificate'] ?? true;
    }
  }

  void _onLookupsChanged() {
    if (mounted) {
      _loadLookups(true);
    }
  }

  Future<void> _loadLookups([bool forceRefresh = true]) async {
    final cats = await HRLookupHelper.instance.getLookupLabels('TRAINING_CATEGORY', forceRefresh: forceRefresh);
    final types = await HRLookupHelper.instance.getLookupLabels('TRAINING_TYPE', forceRefresh: forceRefresh);
    final depts = await HRLookupHelper.instance.getLookupLabels('DEPARTMENT', forceRefresh: forceRefresh);
    final modes = await HRLookupHelper.instance.getLookupLabels('TRAINING_MODE', forceRefresh: forceRefresh);
    final assessments = await HRLookupHelper.instance.getLookupLabels('TRAINING_ASSESSMENT_TYPE', forceRefresh: forceRefresh);
    if (mounted) {
      setState(() {
        _categoryOptions = cats;
        if (!_categoryOptions.contains(_categoryName) && _categoryOptions.isNotEmpty) {
          _categoryName = _categoryOptions.first;
        }
        _trainingTypeOptions = types;
        if (!_trainingTypeOptions.contains(_trainingType) && _trainingTypeOptions.isNotEmpty) {
          _trainingType = _trainingTypeOptions.first;
        }
        _audienceOptions = ['All Staff', ...depts];
        if (!_audienceOptions.contains(_targetAudience) && _audienceOptions.isNotEmpty) {
          _targetAudience = _audienceOptions.first;
        }
        _modeOptions = modes;
        if (!_modeOptions.contains(_mode) && _modeOptions.isNotEmpty) {
          _mode = _modeOptions.first;
        }
        _assessmentOptions = assessments;
        if (!_assessmentOptions.contains(_assessmentType) && _assessmentOptions.isNotEmpty) {
          _assessmentType = _assessmentOptions.first;
        }
      });
    }
  }

  @override
  void dispose() {
    HRLookupHelper.instance.removeListener(_onLookupsChanged);
    _titleController.dispose();
    _descController.dispose();
    _trainerNameController.dispose();
    _providerController.dispose();
    _locationController.dispose();
    _durationController.dispose();
    _durationDisplayController.dispose();
    _capacityController.dispose();
    _budgetController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m:00';
  }

  Future<void> _submit(String targetStatus) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final payload = {
      'title': _titleController.text.trim(),
      'description': _descController.text.trim(),
      'category_name': _categoryName,
      'training_type': _trainingType,
      'is_mandatory': _isMandatory,
      'trainer_type': _trainerType,
      'trainer_name': _trainerNameController.text.trim(),
      'provider_name': _providerController.text.trim(),
      'target_audience': _targetAudience,
      'mode': _mode,
      'location_or_link': _locationController.text.trim(),
      'start_date': _dateFormat.format(_startDate),
      'end_date': _dateFormat.format(_endDate),
      'start_time': _formatTime(_startTime),
      'end_time': _formatTime(_endTime),
      'duration_hours': double.tryParse(_durationController.text.trim()) ?? 2.0,
      'duration_display': _durationDisplayController.text.trim().isNotEmpty
          ? _durationDisplayController.text.trim()
          : '${_durationController.text.trim()} Hours',
      'capacity': int.tryParse(_capacityController.text.trim()) ?? 30,
      'assessment_type': _assessmentType,
      'has_certificate': _hasCertificate,
      'certificate_validity_type': _certValidityType,
      'certificate_validity_months': _certValidityMonths,
      'budget_cost': double.tryParse(_budgetController.text.trim()) ?? 0.0,
      'budget_category': _categoryName,
      'notes': _notesController.text.trim(),
      'status': targetStatus,
    };

    if (widget.initialTraining != null && widget.initialTraining!['skill_gap_id'] != null) {
      payload['skill_gap_id'] = widget.initialTraining!['skill_gap_id'];
    }

    try {
      dynamic res;
      if (widget.initialTraining != null && widget.initialTraining!['id'] != null) {
        res = await _api.put('/training/programs/${widget.initialTraining!['id']}', payload);
      } else {
        res = await _api.post('/training/programs', payload);
      }

      if (res['success'] == true) {
        widget.onTrainingCreated();
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(targetStatus == 'DRAFT'
                  ? 'Training saved as draft'
                  : 'Training program published successfully!'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 860,
        height: 720,
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF13182C) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.school_outlined, color: Color(0xFF4F46E5), size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.initialTraining != null ? 'Edit Training Program' : 'Create Training Program',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'Outfit',
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Configure course parameters, trainer, target audience, schedule, and assessment.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Form Scrollable Body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 10, bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Course Title
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Training Title *',
                          hintText: 'e.g., Advanced Excel for Institutional Data Analysis',
                          prefixIcon: Icon(Icons.title_rounded, size: 20),
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Training title is required' : null,
                      ),
                      const SizedBox(height: 16),

                      // Description
                      TextFormField(
                        controller: _descController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Course Description & Objectives',
                          hintText: 'Provide detailed competencies, pedagogical goals, and curriculum outline...',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Row 1: Category & Type
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _categoryOptions.contains(_categoryName) ? _categoryName : (_categoryOptions.isNotEmpty ? _categoryOptions.first : null),
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Category *',
                                border: OutlineInputBorder(),
                              ),
                              items: _categoryOptions.map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (v) => setState(() => _categoryName = v ?? _categoryName),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _trainingTypeOptions.contains(_trainingType) ? _trainingType : (_trainingTypeOptions.isNotEmpty ? _trainingTypeOptions.first : null),
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Training Type',
                                border: OutlineInputBorder(),
                              ),
                              items: _trainingTypeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (v) => setState(() => _trainingType = v ?? _trainingType),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Row 2: Mandatory Switch & Target Audience
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Mandatory Training', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                        Text(
                                          _isMandatory ? 'Required for all target staff' : 'Optional professional growth',
                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: _isMandatory,
                                    activeThumbColor: const Color(0xFF4F46E5),
                                    onChanged: (v) => setState(() => _isMandatory = v),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _audienceOptions.contains(_targetAudience) ? _targetAudience : (_audienceOptions.isNotEmpty ? _audienceOptions.first : null),
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Target Audience *',
                                border: OutlineInputBorder(),
                              ),
                              items: _audienceOptions.map((a) => DropdownMenuItem(value: a, child: Text(a, overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (v) => setState(() => _targetAudience = v ?? _targetAudience),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Row 3: Trainer Type & Name
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _trainerType,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Trainer Source',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Internal', child: Text('Internal Faculty / Staff')),
                                DropdownMenuItem(value: 'External', child: Text('External Agency / Guest')),
                              ],
                              onChanged: (v) => setState(() => _trainerType = v ?? 'Internal'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _trainerNameController,
                              decoration: const InputDecoration(
                                labelText: 'Trainer / Instructor Name',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Row 4: Mode & Location/Link
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _modeOptions.contains(_mode) ? _mode : (_modeOptions.isNotEmpty ? _modeOptions.first : null),
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Training Mode',
                                border: OutlineInputBorder(),
                              ),
                              items: _modeOptions.map((m) => DropdownMenuItem(value: m, child: Text(m, overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (v) => setState(() => _mode = v ?? _mode),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _locationController,
                              decoration: InputDecoration(
                                labelText: _mode == 'Online' ? 'Meeting URL / Link' : 'Room / Venue Location',
                                hintText: _mode == 'Online' ? 'https://meet.google.com/...' : 'Seminar Hall A',
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Row 5: Dates
                      Row(
                        children: [
                          Expanded(
                            child: Material(
                              color: Colors.transparent,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                shape: RoundedRectangleBorder(
                                  side: BorderSide(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                leading: const Icon(Icons.calendar_today_outlined, size: 20),
                                title: const Text('Start Date', style: TextStyle(fontSize: 12)),
                                subtitle: Text(_dateFormat.format(_startDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                                onTap: () async {
                                  final d = await showDatePicker(
                                    context: context,
                                    initialDate: _startDate,
                                    firstDate: DateTime(2025),
                                    lastDate: DateTime(2030),
                                  );
                                  if (d != null) setState(() => _startDate = d);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Material(
                              color: Colors.transparent,
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                shape: RoundedRectangleBorder(
                                  side: BorderSide(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                leading: const Icon(Icons.event_outlined, size: 20),
                                title: const Text('End Date', style: TextStyle(fontSize: 12)),
                                subtitle: Text(_dateFormat.format(_endDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                                onTap: () async {
                                  final d = await showDatePicker(
                                    context: context,
                                    initialDate: _endDate,
                                    firstDate: DateTime(2025),
                                    lastDate: DateTime(2030),
                                  );
                                  if (d != null) setState(() => _endDate = d);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Row 6: Duration & Capacity
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _durationController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Duration (Hours)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _capacityController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Capacity (Max Seats)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _budgetController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Budget (₹)',
                                prefixText: '₹ ',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Row 7: Assessment & Certificate
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _assessmentOptions.contains(_assessmentType) ? _assessmentType : (_assessmentOptions.isNotEmpty ? _assessmentOptions.first : null),
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Assessment Method',
                                border: OutlineInputBorder(),
                              ),
                              items: _assessmentOptions.map((a) => DropdownMenuItem(value: a, child: Text(a, overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (v) => setState(() => _assessmentType = v ?? _assessmentType),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text('Issue Certificate', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                        Text(
                                          _hasCertificate ? 'On successful completion' : 'No certificate',
                                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(
                                    value: _hasCertificate,
                                    activeThumbColor: const Color(0xFF10B981),
                                    onChanged: (v) => setState(() => _hasCertificate = v),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Notes
                      TextFormField(
                        controller: _notesController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Internal Notes / Instructions',
                          hintText: 'Prerequisites, equipment to bring, room setup...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Actions
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _isSubmitting ? null : () => _submit('DRAFT'),
                    icon: const Icon(Icons.save_outlined, size: 16),
                    label: const Text('Save Draft'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : () => _submit('UPCOMING'),
                    icon: _isSubmitting
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_circle_outline, size: 16, color: Colors.white),
                    label: const Text('Create & Publish', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
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
