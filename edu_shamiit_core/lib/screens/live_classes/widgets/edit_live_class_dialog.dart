import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/live_class_models.dart';
import '../providers/live_class_management_provider.dart';

class EditLiveClassDialog extends ConsumerStatefulWidget {
  final MyClassItem item;

  const EditLiveClassDialog({super.key, required this.item});

  @override
  ConsumerState<EditLiveClassDialog> createState() => _EditLiveClassDialogState();
}

class _EditLiveClassDialogState extends ConsumerState<EditLiveClassDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;

  String? _selectedClassId;
  String? _selectedSectionId;
  String? _selectedSubjectId;
  String? _selectedTeacherId;
  late int _durationMinutes;
  late int _maxParticipants;
  late bool _recordingEnabled;
  late String _status;
  late DateTime _scheduledDate;
  late TimeOfDay _startTime;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.item.topic);
    _descriptionController = TextEditingController(text: widget.item.description);
    _durationMinutes = widget.item.durationMinutes > 0 ? widget.item.durationMinutes : 45;
    _maxParticipants = widget.item.maxParticipants > 0 ? widget.item.maxParticipants : 50;
    _recordingEnabled = widget.item.recordingEnabled;
    _status = widget.item.status.isNotEmpty ? widget.item.status : 'Scheduled';

    _selectedClassId = widget.item.classId;
    _selectedSectionId = widget.item.sectionId;
    _selectedSubjectId = widget.item.subjectId;
    _selectedTeacherId = widget.item.teacherId;

    _scheduledDate = DateTime.now();
    _startTime = const TimeOfDay(hour: 9, minute: 0);

    final meta = ref.read(liveClassManagementProvider).dropdownsData;
    if (meta != null) {
      if (_selectedClassId == null && meta.classes.isNotEmpty) {
        _selectedClassId = meta.classes.first.id;
      }
      final validSections = meta.sections.where((s) => s.classId == _selectedClassId).toList();
      if (_selectedSectionId == null && validSections.isNotEmpty) {
        _selectedSectionId = validSections.first.id;
      }
      final validSubjects = _getValidSubjects(meta, _selectedClassId, _selectedSectionId);
      if (_selectedSubjectId == null && validSubjects.isNotEmpty) {
        _selectedSubjectId = validSubjects.first.id;
      }
      if (_selectedTeacherId == null && meta.teachers.isNotEmpty) {
        _selectedTeacherId = meta.teachers.first.id;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  List<SubjectDropdownItem> _getValidSubjects(MetaDropdownsData? meta, String? classId, String? sectionId) {
    if (meta == null || classId == null || classId.isEmpty) return meta?.subjects ?? [];
    if (meta.classSubjects.isNotEmpty) {
      final matches = meta.classSubjects.where((cs) {
        if (cs.classId != classId) return false;
        if (sectionId != null && sectionId.isNotEmpty && cs.sectionId != null && cs.sectionId!.isNotEmpty) {
          return cs.sectionId == sectionId;
        }
        return true;
      }).toList();
      if (matches.isNotEmpty) {
        final seen = <String>{};
        final list = <SubjectDropdownItem>[];
        for (final m in matches) {
          if (!seen.contains(m.subjectId)) {
            seen.add(m.subjectId);
            list.add(SubjectDropdownItem(
              id: m.subjectId,
              name: m.subjectName,
              icon: m.subjectIcon,
              classId: m.classId,
              sectionId: m.sectionId,
            ));
          }
        }
        return list;
      }
    }
    final classMatches = meta.subjects.where((s) => s.classId == classId).toList();
    if (classMatches.isNotEmpty) return classMatches;
    return meta.subjects;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final scheduledDateTime = DateTime(
        _scheduledDate.year,
        _scheduledDate.month,
        _scheduledDate.day,
        _startTime.hour,
        _startTime.minute,
      );

      final payload = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'class_id': _selectedClassId,
        'section_id': _selectedSectionId,
        'subject_id': _selectedSubjectId,
        'teacher_id': _selectedTeacherId,
        'duration_minutes': _durationMinutes,
        'max_participants': _maxParticipants,
        'status': _status,
        'recording_enabled': _recordingEnabled,
        'scheduled_at': scheduledDateTime.toIso8601String(),
      };

      final success = await ref
          .read(liveClassManagementProvider.notifier)
          .updateMyClass(widget.item.id, payload);

      if (mounted) {
        if (success) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFF10B981),
              content: Text('Live class updated and rescheduled successfully!'),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              backgroundColor: Color(0xFFEF4444),
              content: Text('Failed to update live class. Please try again.'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text('Error updating class: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final meta = ref.watch(liveClassManagementProvider).dropdownsData;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final cardBgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final availableSections = (meta?.sections ?? [])
        .where((s) => s.classId == _selectedClassId)
        .toList();
    final effectiveSectionId = availableSections.any((s) => s.id == _selectedSectionId)
        ? _selectedSectionId
        : (availableSections.isNotEmpty ? availableSections.first.id : null);

    final availableSubjects = _getValidSubjects(meta, _selectedClassId, effectiveSectionId);
    final effectiveSubjectId = availableSubjects.any((s) => s.id == _selectedSubjectId)
        ? _selectedSubjectId
        : (availableSubjects.isNotEmpty ? availableSubjects.first.id : null);

    return Dialog(
      backgroundColor: surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 12,
      child: Container(
        width: 680,
        constraints: const BoxConstraints(maxHeight: 740),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
        ),
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
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.edit_calendar_rounded,
                        color: Color(0xFF2563EB), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Edit & Reschedule Class',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: textPrimary)),
                        Text('Update live session details, assigned cohort, or schedule',
                            style: TextStyle(fontSize: 12, color: textSecondary)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Divider(height: 24, color: borderColor),

              // Form fields scrollable
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Topic
                      Text('Session Topic / Title *',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: textSecondary)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _titleController,
                        style: TextStyle(color: textPrimary),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Title is required' : null,
                        decoration: InputDecoration(
                          hintText: 'e.g. Quadratic Equations - Advanced Solvers',
                          hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.7)),
                          filled: true,
                          fillColor: cardBgColor,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: borderColor)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: borderColor)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Class, Section, Subject strictly cascaded
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Class *',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: textSecondary)),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  value: _selectedClassId,
                                  isExpanded: true,
                                  style: TextStyle(color: textPrimary, fontSize: 13),
                                  dropdownColor: surfaceColor,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: cardBgColor,
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: borderColor)),
                                    enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: borderColor)),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                  ),
                                  items: (meta?.classes ?? [])
                                      .map((c) => DropdownMenuItem(
                                            value: c.id,
                                            child: Text(c.name,
                                                style: TextStyle(color: textPrimary),
                                                overflow: TextOverflow.ellipsis),
                                          ))
                                      .toList(),
                                  onChanged: (v) {
                                    if (v == null) return;
                                    final nextSecs = (meta?.sections ?? []).where((s) => s.classId == v).toList();
                                    final nextSecId = nextSecs.isNotEmpty ? nextSecs.first.id : null;
                                    final nextSubs = _getValidSubjects(meta, v, nextSecId);
                                    final nextSubId = nextSubs.isNotEmpty ? nextSubs.first.id : null;
                                    setState(() {
                                      _selectedClassId = v;
                                      _selectedSectionId = nextSecId;
                                      _selectedSubjectId = nextSubId;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Section *',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: textSecondary)),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  value: effectiveSectionId,
                                  isExpanded: true,
                                  style: TextStyle(color: textPrimary, fontSize: 13),
                                  dropdownColor: surfaceColor,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: cardBgColor,
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: borderColor)),
                                    enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: borderColor)),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                  ),
                                  items: availableSections
                                      .map((s) => DropdownMenuItem(
                                            value: s.id,
                                            child: Text(s.name,
                                                style: TextStyle(color: textPrimary),
                                                overflow: TextOverflow.ellipsis),
                                          ))
                                      .toList(),
                                  onChanged: (v) {
                                    final nextSubs = _getValidSubjects(meta, _selectedClassId, v);
                                    final nextSubId = nextSubs.any((s) => s.id == _selectedSubjectId)
                                        ? _selectedSubjectId
                                        : (nextSubs.isNotEmpty ? nextSubs.first.id : null);
                                    setState(() {
                                      _selectedSectionId = v;
                                      _selectedSubjectId = nextSubId;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Subject *',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: textSecondary)),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  value: effectiveSubjectId,
                                  isExpanded: true,
                                  style: TextStyle(color: textPrimary, fontSize: 13),
                                  dropdownColor: surfaceColor,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: cardBgColor,
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: borderColor)),
                                    enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: borderColor)),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                  ),
                                  items: availableSubjects
                                      .map((s) => DropdownMenuItem(
                                            value: s.id,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(s.icon ?? '📚', style: const TextStyle(fontSize: 13)),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(s.name,
                                                      style: TextStyle(color: textPrimary),
                                                      overflow: TextOverflow.ellipsis),
                                                ),
                                              ],
                                            ),
                                          ))
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _selectedSubjectId = v),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Schedule Date & Time Row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Scheduled Date *',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: textSecondary)),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _scheduledDate,
                                      firstDate: DateTime.now().subtract(const Duration(days: 30)),
                                      lastDate: DateTime.now().add(const Duration(days: 365)),
                                    );
                                    if (picked != null) {
                                      setState(() => _scheduledDate = picked);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: cardBgColor,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: borderColor),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF2563EB)),
                                        const SizedBox(width: 10),
                                        Text(
                                          '${_scheduledDate.day.toString().padLeft(2, '0')}/${_scheduledDate.month.toString().padLeft(2, '0')}/${_scheduledDate.year}',
                                          style: TextStyle(color: textPrimary, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Start Time *',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: textSecondary)),
                                const SizedBox(height: 6),
                                InkWell(
                                  onTap: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: _startTime,
                                    );
                                    if (picked != null) {
                                      setState(() => _startTime = picked);
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: cardBgColor,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: borderColor),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.access_time_rounded, size: 16, color: Color(0xFF2563EB)),
                                        const SizedBox(width: 10),
                                        Text(
                                          _startTime.format(context),
                                          style: TextStyle(color: textPrimary, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Status *',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: textSecondary)),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  value: _status,
                                  isExpanded: true,
                                  style: TextStyle(color: textPrimary, fontSize: 13),
                                  dropdownColor: surfaceColor,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: cardBgColor,
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: borderColor)),
                                    enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: borderColor)),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'Scheduled', child: Text('Scheduled')),
                                    DropdownMenuItem(value: 'Live', child: Text('Live Now')),
                                    DropdownMenuItem(value: 'Completed', child: Text('Completed')),
                                    DropdownMenuItem(value: 'Cancelled', child: Text('Cancelled')),
                                  ],
                                  onChanged: (v) => setState(() => _status = v ?? 'Scheduled'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Duration & Teacher in row
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Duration *',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: textSecondary)),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<int>(
                                  value: _durationMinutes,
                                  isExpanded: true,
                                  style: TextStyle(color: textPrimary, fontSize: 13),
                                  dropdownColor: surfaceColor,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: cardBgColor,
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: borderColor)),
                                    enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: borderColor)),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 30, child: Text('30 Minutes')),
                                    DropdownMenuItem(value: 45, child: Text('45 Minutes')),
                                    DropdownMenuItem(value: 60, child: Text('60 Minutes (1 Hour)')),
                                    DropdownMenuItem(value: 90, child: Text('90 Minutes (1.5 Hours)')),
                                  ],
                                  onChanged: (v) =>
                                      setState(() => _durationMinutes = v ?? 45),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Host Teacher *',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: textSecondary)),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  value: _selectedTeacherId,
                                  isExpanded: true,
                                  style: TextStyle(color: textPrimary, fontSize: 13),
                                  dropdownColor: surfaceColor,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: cardBgColor,
                                    border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: borderColor)),
                                    enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(color: borderColor)),
                                    contentPadding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                  ),
                                  items: (meta?.teachers ?? [])
                                      .map((t) => DropdownMenuItem(
                                            value: t.id,
                                            child: Text(t.fullName,
                                                style: TextStyle(color: textPrimary),
                                                overflow: TextOverflow.ellipsis),
                                          ))
                                      .toList(),
                                  onChanged: (v) =>
                                      setState(() => _selectedTeacherId = v),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Description
                      Text('Description / Syllabus Notes',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: textSecondary)),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 2,
                        style: TextStyle(color: textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Brief notes on topics to cover...',
                          hintStyle: TextStyle(color: textSecondary.withValues(alpha: 0.7)),
                          filled: true,
                          fillColor: cardBgColor,
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: borderColor)),
                          enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: borderColor)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Recording Toggle
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text('Enable Cloud Recording (LiveKit Egress)',
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
                        subtitle: Text('Automatically record MP4 and sync with Recordings tab',
                            style: TextStyle(fontSize: 11, color: textSecondary)),
                        value: _recordingEnabled,
                        activeThumbColor: const Color(0xFF2563EB),
                        onChanged: (v) => setState(() => _recordingEnabled = v),
                      ),
                    ],
                  ),
                ),
              ),

              Divider(height: 24, color: borderColor),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Cancel', style: TextStyle(color: textSecondary)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
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
