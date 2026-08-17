import 'package:flutter/material.dart';
import '../../models/class_models.dart';

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
  late TextEditingController _periodsController;
  late TextEditingController _descriptionController;

  String _type = 'Core';
  String _selectedColor = '#4F46E5';
  String _status = 'ACTIVE';
  final Set<String> _selectedClassIds = {};
  bool _isSaving = false;

  final List<String> _subjectTypes = [
    'Core',
    'Elective',
    'Language',
    'Practical',
    'Activity',
    'Other',
  ];

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
    _periodsController = TextEditingController(text: (s?.periodsPerWeek ?? 5).toString());
    _descriptionController = TextEditingController(text: s?.description ?? '');

    if (s != null) {
      _type = s.type;
      _selectedColor = s.color;
      _status = s.status;
      _selectedClassIds.addAll(s.assignedClassIds);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _periodsController.dispose();
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
      'periods_per_week': int.tryParse(_periodsController.text.trim()) ?? 5,
      'color': _selectedColor,
      'status': _status,
      'class_ids': _selectedClassIds.toList(),
    };

    try {
      await widget.onSave(payload);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _isSaving = false);
    }
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
        width: 580,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
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
                          'Configure subject name, type classification, periods per week, and color tag.',
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

                      // Type & Periods
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
                                      value: _type,
                                      isExpanded: true,
                                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 14),
                                      items: _subjectTypes.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                                      onChanged: (v) => setState(() => _type = v ?? 'Core'),
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
                                _buildFieldLabel('Periods / Week', isDark),
                                const SizedBox(height: 6),
                                TextFormField(
                                  controller: _periodsController,
                                  keyboardType: TextInputType.number,
                                  decoration: _inputDecoration('5', isDark),
                                  style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        ],
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
                      const SizedBox(height: 18),

                      // Target Classes Checkbox Selector (when creating)
                      if (!isEdit && widget.availableClasses.isNotEmpty) ...[
                        _buildFieldLabel('Assign to Classes (Optional)', isDark),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A).withOpacity(0.4) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: widget.availableClasses.map((cls) {
                              final isChecked = _selectedClassIds.contains(cls.id);
                              return FilterChip(
                                label: Text(cls.name, style: TextStyle(fontSize: 12, color: isChecked ? Colors.white : null)),
                                selected: isChecked,
                                selectedColor: const Color(0xFF4F46E5),
                                onSelected: (val) {
                                  setState(() {
                                    if (val) {
                                      _selectedClassIds.add(cls.id);
                                    } else {
                                      _selectedClassIds.remove(cls.id);
                                    }
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      ],
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

  Widget _buildFieldLabel(String label, bool isDark) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
        fontSize: 13,
      ),
      filled: true,
      fillColor: isDark ? const Color(0xFF0F172A) : Colors.white,
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
    );
  }
}
