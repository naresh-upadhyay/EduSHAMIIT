import 'package:flutter/material.dart';
import '../../models/class_models.dart';
import '../../services/class_api_service.dart';

class AssignSubjectToSectionDialog extends StatefulWidget {
  final AcademicSubjectModel subject;
  final List<AcademicClassModel> availableClasses;
  final List<AcademicSectionModel>? availableSections;
  final Function({
    required String classId,
    required List<String> sectionIds,
    String? teacherId,
  }) onSave;

  const AssignSubjectToSectionDialog({
    super.key,
    required this.subject,
    required this.availableClasses,
    this.availableSections,
    required this.onSave,
  });

  @override
  State<AssignSubjectToSectionDialog> createState() => _AssignSubjectToSectionDialogState();
}

class _AssignSubjectToSectionDialogState extends State<AssignSubjectToSectionDialog> {
  final ClassApiService _api = ClassApiService();
  final TextEditingController _teacherSearchController = TextEditingController();

  String? _selectedClassId;
  final Set<String> _selectedSectionIds = {};
  String? _selectedTeacherId;

  List<AcademicTeacherModel> _teachers = [];
  bool _isLoadingTeachers = false;
  bool _isLoadingSections = false;
  bool _isSaving = false;
  final Map<String, List<AcademicSectionModel>> _dynamicClassSections = {};

  @override
  void initState() {
    super.initState();
    if (widget.availableClasses.isNotEmpty) {
      _selectedClassId = widget.availableClasses.first.id;
      final sections = _getSectionsForClass(_selectedClassId!);
      if (sections.isNotEmpty) {
        _selectedSectionIds.add(sections.first.id);
      }
      _fetchFreshSectionsForClass(_selectedClassId!);
    }
    _loadTeachers();
  }

  @override
  void dispose() {
    _teacherSearchController.dispose();
    super.dispose();
  }

  Future<void> _fetchFreshSectionsForClass(String classId) async {
    setState(() => _isLoadingSections = true);
    try {
      final detail = await _api.getClassDetail(classId);
      if (mounted && detail.sections.isNotEmpty) {
        setState(() {
          _dynamicClassSections[classId] = detail.sections;
          if (_selectedSectionIds.isEmpty && detail.sections.isNotEmpty) {
            _selectedSectionIds.add(detail.sections.first.id);
          }
          _isLoadingSections = false;
        });
        return;
      }
    } catch (_) {}
    if (mounted) setState(() => _isLoadingSections = false);
  }

  List<AcademicSectionModel> _getSectionsForClass(String classId) {
    if (_dynamicClassSections.containsKey(classId) && _dynamicClassSections[classId]!.isNotEmpty) {
      return _dynamicClassSections[classId]!;
    }
    final cls = widget.availableClasses.where((c) => c.id == classId).firstOrNull;
    if (cls != null && cls.sections.isNotEmpty) {
      return cls.sections;
    }
    if (widget.availableSections != null) {
      return widget.availableSections!.where((s) => s.classId == classId).toList();
    }
    return [];
  }

  List<AcademicSectionModel> get _currentSections {
    if (_selectedClassId == null) return [];
    return _getSectionsForClass(_selectedClassId!);
  }

  void _onClassChanged(String? classId) {
    if (classId == null) return;
    setState(() {
      _selectedClassId = classId;
      _selectedSectionIds.clear();
      final sections = _getSectionsForClass(classId);
      if (sections.isNotEmpty) {
        _selectedSectionIds.add(sections.first.id);
      }
    });
    _fetchFreshSectionsForClass(classId);
  }

  Future<void> _loadTeachers({String query = ''}) async {
    setState(() => _isLoadingTeachers = true);
    final results = await _api.searchTeachers(search: query, limit: 100);
    if (mounted) {
      setState(() {
        _teachers = results;
        _isLoadingTeachers = false;
      });
    }
  }

  void _submit() async {
    if (_selectedClassId == null) return;

    if (_selectedSectionIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one section to assign this subject.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.onSave(
        classId: _selectedClassId!,
        sectionIds: _selectedSectionIds.toList(),
        teacherId: _selectedTeacherId,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sub = widget.subject;
    final isMandatory = !sub.isElectiveOrOptional;

    final currentSections = _currentSections;
    final hasSections = currentSections.isNotEmpty;
    final allSectionsSelected = hasSections && currentSections.every((s) => _selectedSectionIds.contains(s.id));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        width: 620,
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
                      color: sub.subjectColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.add_task_rounded, color: sub.subjectColor, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Assign ${sub.name}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isMandatory
                                    ? const Color(0xFF10B981).withOpacity(0.15)
                                    : const Color(0xFFF59E0B).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isMandatory ? 'Mandatory' : 'Optional',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: isMandatory ? const Color(0xFF059669) : const Color(0xFFD97706),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Select class, target section(s), and faculty member for this subject.',
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Class Selection
                    Text(
                      'Target Class *',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF334155)),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(8),
                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedClassId,
                          isExpanded: true,
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w600),
                          items: widget.availableClasses.map((cls) {
                            final secCount = _getSectionsForClass(cls.id).length;
                            return DropdownMenuItem(
                              value: cls.id,
                              child: Text('${cls.name} (${cls.code}) • $secCount ${secCount == 1 ? 'Section' : 'Sections'}'),
                            );
                          }).toList(),
                          onChanged: _onClassChanged,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Target Sections Selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Target Section(s) *',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF334155)),
                        ),
                        if (hasSections)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                if (allSectionsSelected) {
                                  _selectedSectionIds.clear();
                                } else {
                                  _selectedSectionIds.addAll(currentSections.map((s) => s.id));
                                }
                              });
                            },
                            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                            child: Text(
                              allSectionsSelected ? 'Deselect All' : 'Select All Sections',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF4F46E5)),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (!hasSections)
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.25)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, size: 22, color: Color(0xFFEF4444)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'No active sections found for this class. Please create at least one section before assigning subjects.',
                                style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626)),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A).withOpacity(0.4) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: currentSections.map((sec) {
                            final isChecked = _selectedSectionIds.contains(sec.id);
                            return FilterChip(
                              label: Text('${sec.name} (${sec.studentsCount} Students)', style: TextStyle(fontSize: 12.5, color: isChecked ? Colors.white : null)),
                              selected: isChecked,
                              selectedColor: const Color(0xFF4F46E5),
                              checkmarkColor: Colors.white,
                              onSelected: (val) {
                                setState(() {
                                  if (val) {
                                    _selectedSectionIds.add(sec.id);
                                  } else {
                                    _selectedSectionIds.remove(sec.id);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    const SizedBox(height: 18),

                    // Enrollment Behavior Information Banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isMandatory
                            ? const Color(0xFF10B981).withOpacity(0.1)
                            : const Color(0xFFF59E0B).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isMandatory
                              ? const Color(0xFF10B981).withOpacity(0.3)
                              : const Color(0xFFF59E0B).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isMandatory ? Icons.check_circle_outline_rounded : Icons.info_outline_rounded,
                            color: isMandatory ? const Color(0xFF059669) : const Color(0xFFD97706),
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isMandatory
                                      ? 'Automatic Student Enrollment (Mandatory Subject)'
                                      : 'Selective Enrollment (Optional / Elective Subject)',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: isMandatory ? const Color(0xFF059669) : const Color(0xFFD97706),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isMandatory
                                      ? 'All students active in the selected target will automatically be enrolled in this subject upon assignment.'
                                      : 'Subject starts with 0 enrolled students. You can search and enroll students specifically within each section.',
                                  style: TextStyle(fontSize: 11.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Subject Teacher Search & Selection (Optional)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Subject Teacher (Optional)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF334155)),
                        ),
                        if (_selectedTeacherId != null)
                          TextButton(
                            onPressed: () => setState(() => _selectedTeacherId = null),
                            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                            child: const Text('Clear Selection', style: TextStyle(fontSize: 11.5, color: Color(0xFFEF4444))),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),

                    // Search input
                    TextField(
                      controller: _teacherSearchController,
                      onChanged: (val) => _loadTeachers(query: val),
                      style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: 'Search faculty from school by name, emp ID, or dept...',
                        hintStyle: TextStyle(color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8), fontSize: 12.5),
                        prefixIcon: Icon(Icons.search, size: 18, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                        filled: true,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Teachers List
                    Container(
                      height: 180,
                      decoration: BoxDecoration(
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(8),
                        color: isDark ? const Color(0xFF0F172A).withOpacity(0.3) : const Color(0xFFF8FAFC),
                      ),
                      child: _isLoadingTeachers
                          ? const Center(child: CircularProgressIndicator())
                          : _teachers.isEmpty
                              ? Center(
                                  child: Text(
                                    'No faculty members found.',
                                    style: TextStyle(fontSize: 12.5, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                  ),
                                )
                              : ListView.separated(
                                  padding: const EdgeInsets.all(8),
                                  itemCount: _teachers.length,
                                  separatorBuilder: (_, __) => const Divider(height: 8),
                                  itemBuilder: (context, index) {
                                    final t = _teachers[index];
                                    final isSelected = _selectedTeacherId == t.id;

                                    return InkWell(
                                      onTap: () {
                                        setState(() {
                                          if (isSelected) {
                                            _selectedTeacherId = null;
                                          } else {
                                            _selectedTeacherId = t.id;
                                          }
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(6),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? const Color(0xFF4F46E5).withOpacity(0.12)
                                              : Colors.transparent,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 16,
                                              backgroundColor: const Color(0xFF4F46E5).withOpacity(0.15),
                                              backgroundImage: t.avatarUrl != null ? NetworkImage(t.avatarUrl!) : null,
                                              child: t.avatarUrl == null
                                                  ? Text(
                                                      t.fullName.isNotEmpty ? t.fullName[0].toUpperCase() : 'T',
                                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)),
                                                    )
                                                  : null,
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    t.fullName,
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w600,
                                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                    ),
                                                  ),
                                                  Text(
                                                    '${t.employeeId ?? 'EMP'} • ${t.department ?? 'Faculty'} • ${t.email ?? ''}',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Radio<String?>(
                                              value: t.id,
                                              groupValue: _selectedTeacherId,
                                              activeColor: const Color(0xFF4F46E5),
                                              onChanged: (val) => setState(() => _selectedTeacherId = val),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ],
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_selectedSectionIds.length} Section(s) Selected',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _selectedSectionIds.isNotEmpty
                          ? const Color(0xFF4F46E5)
                          : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                    ),
                  ),
                  Row(
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
                            : const Text('Assign Subject', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ],
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
