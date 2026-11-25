import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../classes/providers/class_provider.dart';
import '../models/live_class_models.dart';
import '../providers/live_class_management_provider.dart';

class RecordingEditDialog extends ConsumerStatefulWidget {
  final RecordingItem recording;

  const RecordingEditDialog({super.key, required this.recording});

  static Future<bool?> show(BuildContext context, RecordingItem recording) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => RecordingEditDialog(recording: recording),
    );
  }

  @override
  ConsumerState<RecordingEditDialog> createState() => _RecordingEditDialogState();
}

class _RecordingEditDialogState extends ConsumerState<RecordingEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _teacherCtrl;
  late final TextEditingController _durationCtrl;
  late final TextEditingController _descCtrl;

  String? _selectedClassId;
  String? _selectedSectionId;
  String? _selectedSubjectId;
  late String _visibility;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.recording.title);
    _teacherCtrl = TextEditingController(text: widget.recording.teacherName);
    final mins = (widget.recording.durationSeconds / 60).round().clamp(1, 999);
    _durationCtrl = TextEditingController(text: mins.toString());
    _descCtrl = TextEditingController(text: widget.recording.description ?? '');
    _selectedClassId = widget.recording.classId;
    _selectedSectionId = widget.recording.sectionId;
    _selectedSubjectId = widget.recording.subjectId;
    _visibility = widget.recording.visibility.toUpperCase();
    if (!['CLASS', 'SCHOOL', 'PRIVATE'].contains(_visibility)) {
      _visibility = _visibility == 'SHARED' ? 'SCHOOL' : 'CLASS';
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(classProvider.notifier).fetchClasses();
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _teacherCtrl.dispose();
    _durationCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final mins = int.tryParse(_durationCtrl.text.trim()) ?? 1;
    final ok = await ref.read(liveClassManagementProvider.notifier).updateRecording(
      widget.recording.id,
      {
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        if (_selectedClassId != null && _selectedClassId!.isNotEmpty) 'class_id': _selectedClassId,
        if (_selectedSectionId != null && _selectedSectionId!.isNotEmpty) 'section_id': _selectedSectionId,
        if (_selectedSubjectId != null && _selectedSubjectId!.isNotEmpty) 'subject_id': _selectedSubjectId,
        'teacher_name': _teacherCtrl.text.trim(),
        'visibility': _visibility,
        'duration_minutes': mins,
      },
    );

    if (!mounted) return;
    setState(() => _isSaving = false);
    Navigator.of(context).pop(ok);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Recording updated successfully.' : 'Failed to update recording.'),
        backgroundColor: ok ? const Color(0xFF10B981) : const Color(0xFFEF4444),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E222D) : Colors.white;
    final border = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final inputFill = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    final meta = ref.watch(liveClassManagementProvider).dropdownMeta;
    final classState = ref.watch(classProvider);

    final classMap = <String, Map<String, dynamic>>{};
    for (final c in classState.availableClasses) {
      if (c.id.isNotEmpty && c.name.isNotEmpty) {
        classMap[c.id] = <String, dynamic>{
          'id': c.id,
          'name': c.name,
          'sections': c.sections
              .map<Map<String, dynamic>>((s) => <String, dynamic>{'id': s.id, 'name': s.name})
              .toList(),
          'subjects': c.subjects
              .map<Map<String, dynamic>>((sub) => <String, dynamic>{'id': sub.id, 'name': sub.name})
              .toList(),
        };
      }
    }
    if (meta != null) {
      for (final c in meta.classes) {
        classMap.putIfAbsent(c.id, () => <String, dynamic>{
          'id': c.id,
          'name': c.name,
          'sections': <Map<String, dynamic>>[],
          'subjects': <Map<String, dynamic>>[],
        });
      }
      for (final s in meta.sections) {
        final existing = classMap[s.classId]?['sections'] as List<Map<String, dynamic>>?;
        if (existing != null && !existing.any((e) => e['id'] == s.id)) {
          existing.add(<String, dynamic>{'id': s.id, 'name': s.name});
        }
      }
      for (final cs in meta.classSubjects) {
        final existing = classMap[cs.classId]?['subjects'] as List<Map<String, dynamic>>?;
        if (existing != null && !existing.any((e) => e['id'] == cs.subjectId)) {
          existing.add(<String, dynamic>{'id': cs.subjectId, 'name': cs.subjectName});
        }
      }
    }

    final sortedClasses = classMap.values.toList()
      ..sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

    if ((_selectedClassId == null || !classMap.containsKey(_selectedClassId)) && sortedClasses.isNotEmpty) {
      final matched = sortedClasses.where((c) =>
          widget.recording.classSection.toLowerCase().contains((c['name'] as String).toLowerCase())).firstOrNull;
      _selectedClassId = (matched ?? sortedClasses.first)['id'] as String;
    }

    final currentClass = _selectedClassId != null ? classMap[_selectedClassId] : null;
    final sections = (currentClass?['sections'] as List<Map<String, dynamic>>? ?? []);
    if (_selectedSectionId != null && sections.isNotEmpty && !sections.any((s) => s['id'] == _selectedSectionId)) {
      _selectedSectionId = sections.first['id'] as String;
    }
    _selectedSectionId ??= sections.isNotEmpty ? sections.first['id'] as String : null;

    var subjects = (currentClass?['subjects'] as List<Map<String, dynamic>>? ?? []);
    if (subjects.isEmpty && meta != null) {
      subjects = meta.subjects.map((e) => {'id': e.id, 'name': e.name}).toList();
    }
    if (_selectedSubjectId != null && subjects.isNotEmpty && !subjects.any((s) => s['id'] == _selectedSubjectId)) {
      final matched = subjects.where((s) =>
          (s['name'] as String).toLowerCase() == widget.recording.subjectName.toLowerCase()).firstOrNull;
      _selectedSubjectId = (matched ?? subjects.first)['id'] as String;
    }
    _selectedSubjectId ??= subjects.isNotEmpty ? subjects.first['id'] as String : null;

    return Dialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.edit_note_rounded, color: Color(0xFF3B82F6), size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Edit Recording', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textPrimary)),
                          Text('Update recording metadata, class mapping, and audience visibility.', style: TextStyle(fontSize: 11.5, color: textSecondary)),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
                      icon: Icon(Icons.close_rounded, color: textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Recording Title *', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textPrimary)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _titleCtrl,
                  style: TextStyle(fontSize: 13, color: textPrimary),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: inputFill,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: border)),
                  ),
                ),
                const SizedBox(height: 12),
                if (sortedClasses.isNotEmpty) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Class', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textPrimary)),
                            const SizedBox(height: 6),
                            AppSearchableDropdown<String>.fromMenuItems(
                              value: _selectedClassId,
                              isDense: true,
                              dropdownColor: bg,
                              style: TextStyle(fontSize: 12.5, color: textPrimary),
                              items: sortedClasses.map((c) => DropdownMenuItem<String>(value: c['id'] as String, child: Text(c['name'] as String))).toList(),
                              onChanged: (val) => setState(() {
                                _selectedClassId = val;
                                _selectedSectionId = null;
                                _selectedSubjectId = null;
                              }),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      if (sections.isNotEmpty)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Section', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textPrimary)),
                              const SizedBox(height: 6),
                              AppSearchableDropdown<String>.fromMenuItems(
                                value: _selectedSectionId,
                                isDense: true,
                                dropdownColor: bg,
                                style: TextStyle(fontSize: 12.5, color: textPrimary),
                                items: sections.map((s) => DropdownMenuItem<String>(value: s['id'] as String, child: Text(s['name'] as String))).toList(),
                                onChanged: (val) => setState(() => _selectedSectionId = val),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    if (subjects.isNotEmpty)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Subject', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textPrimary)),
                            const SizedBox(height: 6),
                            AppSearchableDropdown<String>.fromMenuItems(
                              value: _selectedSubjectId,
                              isDense: true,
                              dropdownColor: bg,
                              style: TextStyle(fontSize: 12.5, color: textPrimary),
                              items: subjects.map((s) => DropdownMenuItem<String>(value: s['id'] as String, child: Text(s['name'] as String))).toList(),
                              onChanged: (val) => setState(() => _selectedSubjectId = val),
                            ),
                          ],
                        ),
                      ),
                    if (subjects.isNotEmpty) const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Instructor / Host', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textPrimary)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _teacherCtrl,
                            style: TextStyle(fontSize: 12.5, color: textPrimary),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: inputFill,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: border)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: border)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 95,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Duration (min)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textPrimary)),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _durationCtrl,
                            keyboardType: TextInputType.number,
                            style: TextStyle(fontSize: 12.5, color: textPrimary),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: inputFill,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: border)),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: border)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Audience Visibility', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textPrimary)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _visPill('CLASS', 'Class Only', Icons.group_outlined),
                    const SizedBox(width: 8),
                    _visPill('SCHOOL', 'Entire School', Icons.domain_rounded),
                    const SizedBox(width: 8),
                    _visPill('PRIVATE', 'Private (Teachers)', Icons.lock_outline_rounded),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Lesson Summary & Notes', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: textPrimary)),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 3,
                  style: TextStyle(fontSize: 12.5, color: textPrimary),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: inputFill,
                    hintText: 'Topics covered, homework instructions, chapters...',
                    hintStyle: TextStyle(fontSize: 12, color: textSecondary),
                    contentPadding: const EdgeInsets.all(10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: border)),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_rounded, size: 16),
                      label: Text(_isSaving ? 'Saving...' : 'Save Changes'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _visPill(String code, String label, IconData icon) {
    final selected = _visibility == code;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _visibility = code),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF2563EB).withValues(alpha: 0.16) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? const Color(0xFF3B82F6) : const Color(0xFF475569).withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: selected ? const Color(0xFF60A5FA) : Colors.grey),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                    color: selected ? const Color(0xFF60A5FA) : Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
