import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/live_class_models.dart';
import '../providers/live_class_management_provider.dart';

class CreateInstantClassDialog extends ConsumerStatefulWidget {
  const CreateInstantClassDialog({super.key});

  @override
  ConsumerState<CreateInstantClassDialog> createState() =>
      _CreateInstantClassDialogState();
}

class _CreateInstantClassDialogState
    extends ConsumerState<CreateInstantClassDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController =
      TextEditingController(text: 'Quadratic Equations');
  final _descriptionController = TextEditingController(
      text:
          'Dynamic live problem solving workshop covering standard form and factorization');

  String? _selectedClassId;
  String? _selectedSectionId;
  String? _selectedSubjectId;
  String? _selectedTeacherId;
  int _durationMinutes = 45;

  bool _recordingEnabled = true;
  bool _waitingRoomEnabled = false;
  bool _allowStudentShare = false;
  bool _allowStudentMic = true;
  bool _allowStudentCam = true;
  final bool _allowChat = true;
  final bool _allowReactions = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final meta = ref.read(liveClassManagementProvider).dropdownsData;
    if (meta != null) {
      if (meta.classes.isNotEmpty) {
        _selectedClassId = meta.classes.first.id;
        final validSections = meta.sections.where((s) => s.classId == _selectedClassId).toList();
        if (validSections.isNotEmpty) {
          _selectedSectionId = validSections.first.id;
        } else if (meta.sections.isNotEmpty) {
          _selectedSectionId = meta.sections.first.id;
        }
        final validSubjects = _getValidSubjects(meta, _selectedClassId, _selectedSectionId);
        if (validSubjects.isNotEmpty) {
          _selectedSubjectId = validSubjects.first.id;
        } else if (meta.subjects.isNotEmpty) {
          _selectedSubjectId = meta.subjects.first.id;
        }
      }
      if (meta.teachers.isNotEmpty) _selectedTeacherId = meta.teachers.first.id;
    }
  }

  List<SubjectDropdownItem> _getValidSubjects(MetaDropdownsData? meta, String? classId, String? sectionId) {
    if (meta == null || classId == null || classId.isEmpty) return meta?.subjects ?? [];
    // 1. Check class_subjects mapping from class management
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
    // 2. Fallback to subjects assigned to classId
    final classMatches = meta.subjects.where((s) => s.classId == classId).toList();
    if (classMatches.isNotEmpty) return classMatches;
    return meta.subjects;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final payload = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'class_id': _selectedClassId,
        'section_id': _selectedSectionId,
        'subject_id': _selectedSubjectId,
        'teacher_id': _selectedTeacherId,
        'duration_minutes': _durationMinutes,
        'recording_enabled': _recordingEnabled,
        'waiting_room_enabled': _waitingRoomEnabled,
        'allow_student_share': _allowStudentShare,
        'allow_student_mic': _allowStudentMic,
        'allow_student_cam': _allowStudentCam,
        'allow_chat': _allowChat,
        'allow_reactions': _allowReactions,
      };

      await ref
          .read(liveClassManagementProvider.notifier)
          .createInstantClass(payload);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF10B981),
            content: Text('Live class created successfully! Ready to join.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text('Failed to create live class: $e'),
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
                      color: const Color(0xFF2563EB).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.video_call_rounded,
                        color: Color(0xFF2563EB), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create New Live Class',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          'Start an instant classroom or configure authorized participants and settings',
                          style: TextStyle(
                            fontSize: 13,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: textSecondary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              Divider(height: 28, color: borderColor),

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
                      Builder(builder: (context) {
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

                        return Row(
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
                                  AppSearchableDropdownFormField<String>.fromMenuItems(
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
                                  AppSearchableDropdownFormField<String>.fromMenuItems(
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
                                  AppSearchableDropdownFormField<String>.fromMenuItems(
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
                        );
                      }),
                      const SizedBox(height: 16),

                      // Teacher & Duration in row
                      Row(
                        children: [
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
                                AppSearchableDropdownFormField<String>.fromMenuItems(
                                  initialValue: _selectedTeacherId,
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
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Duration (Minutes)',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: textSecondary)),
                                const SizedBox(height: 6),
                                AppSearchableDropdownFormField<int>.fromMenuItems(
                                  initialValue: _durationMinutes,
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
                                    DropdownMenuItem(value: 60, child: Text('60 Minutes')),
                                    DropdownMenuItem(value: 90, child: Text('90 Minutes')),
                                  ],
                                  onChanged: (v) {
                                    if (v != null) setState(() => _durationMinutes = v);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Toggles Grid
                      Text('Classroom & Security Controls',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: textPrimary)),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: cardBgColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          children: [
                            SwitchListTile(
                              title: Text('Auto Recording via LiveKit Egress',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
                              subtitle: Text('Automatically record and store MP4 video in cloud storage',
                                  style: TextStyle(fontSize: 11, color: textSecondary)),
                              value: _recordingEnabled,
                              activeThumbColor: const Color(0xFF2563EB),
                              onChanged: (v) => setState(() => _recordingEnabled = v),
                              dense: true,
                            ),
                            Divider(height: 8, color: borderColor),
                            SwitchListTile(
                              title: Text('Waiting Room & Guest Approval',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
                              subtitle: Text('Host must admit students before they can enter meeting room',
                                  style: TextStyle(fontSize: 11, color: textSecondary)),
                              value: _waitingRoomEnabled,
                              activeThumbColor: const Color(0xFF2563EB),
                              onChanged: (v) => setState(() => _waitingRoomEnabled = v),
                              dense: true,
                            ),
                            Divider(height: 8, color: borderColor),
                            SwitchListTile(
                              title: Text('Allow Student Microphones',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
                              value: _allowStudentMic,
                              activeThumbColor: const Color(0xFF2563EB),
                              onChanged: (v) => setState(() => _allowStudentMic = v),
                              dense: true,
                            ),
                            Divider(height: 8, color: borderColor),
                            SwitchListTile(
                              title: Text('Allow Student Webcams',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
                              value: _allowStudentCam,
                              activeThumbColor: const Color(0xFF2563EB),
                              onChanged: (v) => setState(() => _allowStudentCam = v),
                              dense: true,
                            ),
                            Divider(height: 8, color: borderColor),
                            SwitchListTile(
                              title: Text('Allow Student Screen Sharing',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary)),
                              value: _allowStudentShare,
                              activeThumbColor: const Color(0xFF2563EB),
                              onChanged: (v) => setState(() => _allowStudentShare = v),
                              dense: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      side: BorderSide(color: borderColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text('Cancel', style: TextStyle(color: textSecondary)),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.play_circle_fill_rounded, size: 18),
                    label: Text(_isSubmitting ? 'Starting...' : 'Start Class Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2563EB),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
