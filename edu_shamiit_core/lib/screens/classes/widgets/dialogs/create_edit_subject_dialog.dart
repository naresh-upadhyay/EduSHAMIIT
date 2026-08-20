import 'package:flutter/material.dart';
import '../../models/class_models.dart';
import '../../services/academic_lookup_helper.dart';

class CreateEditSubjectDialog extends StatefulWidget {
  final AcademicSubjectModel? subjectToEdit;
  final List<AcademicClassModel> availableClasses;
  final Function(Map<String, dynamic> data) onSave;

  const CreateEditSubjectDialog({
    super.key,
    this.subjectToEdit,
    this.availableClasses = const [],
    required this.onSave,
  });

  @override
  State<CreateEditSubjectDialog> createState() => _CreateEditSubjectDialogState();
}

class _CreateEditSubjectDialogState extends State<CreateEditSubjectDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _codeController;
  late TextEditingController _descriptionController;

  String _type = 'Core';
  String _selectedColor = '#4F46E5';
  String _status = 'ACTIVE';
  bool _isOptional = false;
  bool _isSaving = false;

  List<AcademicLookupItem> _subjectTypes = [];
  List<AcademicLookupItem> _statuses = [];

  final List<String> _presetColors = [
    '#4F46E5', // Indigo
    '#06B6D4', // Cyan
    '#10B981', // Emerald
    '#F59E0B', // Amber
    '#EC4899', // Pink
    '#8B5CF6', // Purple
    '#EF4444', // Red
    '#64748B', // Slate
  ];

  @override
  void initState() {
    super.initState();
    final s = widget.subjectToEdit;
    _nameController = TextEditingController(text: s?.name ?? '');
    _codeController = TextEditingController(text: s?.code ?? '');
    _descriptionController = TextEditingController(text: s?.description ?? '');

    if (s != null) {
      _type = s.type;
      _selectedColor = s.color;
      _status = s.status;
      _isOptional = s.isOptional;
    } else {
      _isOptional = false;
    }
    _loadLookups();
  }

  Future<void> _loadLookups() async {
    final helper = AcademicLookupHelper.instance;
    final results = await Future.wait([
      helper.getActiveLookup('SUBJECT_TYPE'),
      helper.getActiveLookup('ACADEMIC_STATUS'),
    ]);

    if (mounted) {
      setState(() {
        _subjectTypes = List<AcademicLookupItem>.from(results[0]);
        _statuses = List<AcademicLookupItem>.from(results[1]);
        if (_subjectTypes.isNotEmpty && !_subjectTypes.any((t) => t.label.toLowerCase() == _type.toLowerCase())) {
          _type = _subjectTypes.first.label;
        }
        if (_status.isNotEmpty) {
          final matched = _statuses.where((s) =>
              s.code.toUpperCase() == _status.toUpperCase() ||
              s.label.toUpperCase() == _status.toUpperCase()).firstOrNull;
          if (matched != null) {
            _status = matched.code;
          } else {
            _statuses.add(AcademicLookupItem(id: _status, code: _status, label: _status));
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final payload = {
      'name': _nameController.text.trim(),
      'code': _codeController.text.trim().toUpperCase(),
      'type': _type,
      'description': _descriptionController.text.trim(),
      'color': _selectedColor,
      'status': _status,
      'is_optional': _isOptional,
    };

    try {
      await widget.onSave(payload);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  InputDecoration _inputDecoration(String hint, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), fontSize: 13),
      filled: true,
      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF4F46E5), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
    );
  }

  Widget _buildFieldLabel(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white70 : const Color(0xFF334155),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.subjectToEdit != null;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        width: 600,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.90),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.menu_book_rounded, color: Color(0xFF6366F1), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit ? 'Edit Subject' : 'Add Subject to Catalog',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Configure subject name, type classification, mandatory/optional status, and color tag.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, size: 20, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),

            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Subject Name & Code
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Subject Name *', isDark),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _nameController,
                                  decoration: _inputDecoration('e.g. Mathematics', isDark),
                                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 14),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Subject name is required' : null,
                                  onChanged: (v) {
                                    if (!isEdit && _codeController.text.isEmpty) {
                                      final raw = v.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
                                      _codeController.text = raw.length > 5 ? raw.substring(0, 5) : raw;
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Subject Code *', isDark),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _codeController,
                                  decoration: _inputDecoration('e.g. MATH', isDark),
                                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 14),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Code is required' : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Subject Type & Status
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Subject Type', isDark),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                    borderRadius: BorderRadius.circular(8),
                                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _subjectTypes.any((t) => t.label.toLowerCase() == _type.toLowerCase())
                                          ? _subjectTypes.firstWhere((t) => t.label.toLowerCase() == _type.toLowerCase()).label
                                          : (_subjectTypes.isNotEmpty ? _subjectTypes.first.label : _type),
                                      isExpanded: true,
                                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 14),
                                      items: _subjectTypes.map((t) => DropdownMenuItem(value: t.label, child: Text(t.label))).toList(),
                                      onChanged: (v) {
                                        if (v != null) {
                                          setState(() {
                                            _type = v;
                                            if (v.toLowerCase() == 'elective' || v.toLowerCase() == 'optional') {
                                              _isOptional = true;
                                            } else if (v.toLowerCase() == 'core') {
                                              _isOptional = false;
                                            }
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Status', isDark),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                    borderRadius: BorderRadius.circular(8),
                                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _statuses.any((s) => s.code.toUpperCase() == _status.toUpperCase())
                                          ? _statuses.firstWhere((s) => s.code.toUpperCase() == _status.toUpperCase()).code
                                          : (_statuses.isNotEmpty ? _statuses.first.code : _status),
                                      isExpanded: true,
                                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 14),
                                      items: _statuses.map((s) => DropdownMenuItem(value: s.code, child: Text(s.label))).toList(),
                                      onChanged: (v) => setState(() => _status = v ?? 'ACTIVE'),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Mandatory vs Optional Enrollment Rule Card
                      _buildFieldLabel('Subject Requirement & Enrollment Mode *', isDark),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A).withOpacity(0.5) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          children: [
                            RadioListTile<bool>(
                              title: Row(
                                children: [
                                  const Text('Mandatory (Compulsory)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('Auto-Enrolls All Students', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF059669))),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                'When assigned to a class/section, all enrolled students are automatically assigned to this subject.',
                                style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                              value: false,
                              groupValue: _isOptional,
                              activeColor: const Color(0xFF4F46E5),
                              contentPadding: EdgeInsets.zero,
                              onChanged: (val) => setState(() => _isOptional = val ?? false),
                            ),
                            const Divider(height: 12),
                            RadioListTile<bool>(
                              title: Row(
                                children: [
                                  const Text('Optional / Elective', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text('Selective Enrollment', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFFD97706))),
                                  ),
                                ],
                              ),
                              subtitle: Text(
                                'Subject starts with 0 enrolled students. Admin selectively searches and enrolls students within the section.',
                                style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                              ),
                              value: true,
                              groupValue: _isOptional,
                              activeColor: const Color(0xFF4F46E5),
                              contentPadding: EdgeInsets.zero,
                              onChanged: (val) => setState(() => _isOptional = val ?? true),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // Color Palette Picker
                      _buildFieldLabel('Subject Color Tag', isDark),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 10,
                        children: _presetColors.map((hex) {
                          final isSelected = _selectedColor.toUpperCase() == hex.toUpperCase();
                          final c = Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
                          return GestureDetector(
                            onTap: () => setState(() => _selectedColor = hex),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: c,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(color: isDark ? Colors.white : const Color(0xFF0F172A), width: 3)
                                    : null,
                                boxShadow: isSelected
                                    ? [BoxShadow(color: c.withOpacity(0.4), blurRadius: 8, spreadRadius: 1)]
                                    : null,
                              ),
                              child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 18),

                      // Description
                      _buildFieldLabel('Description (Optional)', isDark),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 2,
                        decoration: _inputDecoration('Brief summary of syllabus or curriculum...', isDark),
                        style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A).withOpacity(0.5) : const Color(0xFFF8FAFC),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(
                            isEdit ? 'Save Changes' : 'Add Subject',
                            style: const TextStyle(fontWeight: FontWeight.w600),
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
