import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/class_models.dart';
import '../../providers/class_provider.dart';
import '../../services/class_api_service.dart';

class AssignSubjectTeacherDialog extends ConsumerStatefulWidget {
  final AcademicSubjectModel? defaultSubject;
  final AcademicClassModel? defaultClass;
  final AcademicSectionModel? defaultSection;
  final String? defaultClassId;
  final String? defaultClassName;
  final String? defaultSectionId;
  final String? defaultSectionName;
  final AcademicTeacherModel? defaultTeacher;
  final List<AcademicClassModel> availableClasses;

  const AssignSubjectTeacherDialog({
    super.key,
    this.defaultSubject,
    this.defaultClass,
    this.defaultSection,
    this.defaultClassId,
    this.defaultClassName,
    this.defaultSectionId,
    this.defaultSectionName,
    this.defaultTeacher,
    this.availableClasses = const [],
  });

  @override
  ConsumerState<AssignSubjectTeacherDialog> createState() => _AssignSubjectTeacherDialogState();
}

class _AssignSubjectTeacherDialogState extends ConsumerState<AssignSubjectTeacherDialog> {
  final ClassApiService _api = ClassApiService();
  final TextEditingController _searchController = TextEditingController();

  String? _selectedClassId;
  String? _selectedSubjectId;
  String? _selectedTeacherId;
  AcademicTeacherModel? _initialTeacher;
  final Set<String> _selectedSectionIds = {};

  List<AcademicTeacherModel> _teachers = [];
  bool _isLoadingTeachers = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedClassId = widget.defaultClass?.id ??
        widget.defaultClassId ??
        (widget.availableClasses.isNotEmpty ? widget.availableClasses.first.id : null);

    if (widget.defaultSection?.id != null) {
      _selectedSectionIds.add(widget.defaultSection!.id);
    } else if (widget.defaultSectionId != null && widget.defaultSectionId!.isNotEmpty) {
      _selectedSectionIds.add(widget.defaultSectionId!);
    } else if (_currentSections.isNotEmpty) {
      _selectedSectionIds.add(_currentSections.first.id);
    }

    if (widget.defaultSubject != null) {
      _selectedSubjectId = widget.defaultSubject!.id;
    }

    _initialTeacher = widget.defaultTeacher;
    _selectedTeacherId = widget.defaultTeacher?.id;

    _loadTeachers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  AcademicClassModel? get _currentClass {
    if (_selectedClassId == null) return null;
    return widget.availableClasses.where((c) => c.id == _selectedClassId).firstOrNull;
  }

  List<AcademicSectionModel> get _currentSections {
    return _currentClass?.sections ?? [];
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
    if (_selectedClassId == null || _selectedSubjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select class and subject.')),
      );
      return;
    }

    if (_selectedSectionIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one section.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    final notifier = ref.read(classProvider.notifier);
    final ok = await notifier.assignSectionSubjectTeacher(
      classId: _selectedClassId!,
      sectionIds: _selectedSectionIds.toList(),
      subjectId: _selectedSubjectId!,
      teacherId: _selectedTeacherId,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _selectedTeacherId == null
                  ? 'Teacher unassigned successfully.'
                  : 'Teacher assigned successfully.',
            ),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        Navigator.of(context).pop(true);
      }
    }
  }

  void _unassignDirectly() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(
          children: [
            Icon(Icons.person_remove_rounded, color: Color(0xFFEF4444), size: 22),
            SizedBox(width: 8),
            Text('Unassign Teacher?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
          'Are you sure you want to unassign ${_initialTeacher?.fullName ?? "the current teacher"} from this subject section?',
          style: const TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            child: const Text('Unassign'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() {
        _selectedTeacherId = null;
      });
      _submit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sub = widget.defaultSubject;

    final displayClassName = widget.defaultClassName ?? widget.defaultClass?.name ?? _currentClass?.name ?? 'Class';
    final displaySectionName = widget.defaultSectionName ?? widget.defaultSection?.name ?? (_currentSections.isNotEmpty ? _currentSections.first.name : 'All Sections');

    final bool hasInitialTeacher = _initialTeacher != null;
    final bool isUnassignSelected = _selectedTeacherId == null && hasInitialTeacher;

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
                      color: const Color(0xFF4F46E5).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.person_pin_rounded, color: Color(0xFF4F46E5), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assign Subject Teacher',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          sub != null
                              ? 'Assign or change faculty member for ${sub.name}.'
                              : 'Select class, sections, and faculty member for subject.',
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
                    // Class & Section Info
                    if (widget.defaultClass != null || widget.defaultClassId != null) ...[
                      Text(
                        'Class & Section',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF334155)),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.school_outlined, size: 18, color: Color(0xFF4F46E5)),
                            const SizedBox(width: 8),
                            Text(
                              '$displayClassName • Section $displaySectionName',
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Text(
                        'Target Class',
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
                            style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13.5, fontWeight: FontWeight.w600),
                            items: widget.availableClasses.map((cls) {
                              return DropdownMenuItem(
                                value: cls.id,
                                child: Text(cls.name),
                              );
                            }).toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() {
                                  _selectedClassId = v;
                                  _selectedSectionIds.clear();
                                  final cls = widget.availableClasses.where((c) => c.id == v).firstOrNull;
                                  if (cls != null && cls.sections.isNotEmpty) {
                                    _selectedSectionIds.add(cls.sections.first.id);
                                  }
                                });
                              }
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Sections',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF334155)),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A).withOpacity(0.4) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _currentSections.map((sec) {
                            final isChecked = _selectedSectionIds.contains(sec.id);
                            return FilterChip(
                              label: Text(sec.name, style: TextStyle(fontSize: 12, color: isChecked ? Colors.white : null)),
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
                    ],

                    // Currently Assigned Teacher Card
                    if (hasInitialTeacher) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: const Color(0xFF10B981).withOpacity(0.2),
                              backgroundImage: _initialTeacher!.avatarUrl != null ? NetworkImage(_initialTeacher!.avatarUrl!) : null,
                              child: _initialTeacher!.avatarUrl == null
                                  ? Text(
                                      _initialTeacher!.fullName.isNotEmpty ? _initialTeacher!.fullName[0].toUpperCase() : 'T',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        _initialTeacher!.fullName,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'CURRENTLY ASSIGNED',
                                          style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_initialTeacher!.employeeId ?? "EMP"} • ${_initialTeacher!.department ?? "Faculty"} • ${_initialTeacher!.email ?? ""}',
                                    style: TextStyle(fontSize: 11, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _isSaving ? null : _unassignDirectly,
                              icon: const Icon(Icons.person_remove_outlined, size: 14, color: Color(0xFFEF4444)),
                              label: const Text('Unassign', style: TextStyle(fontSize: 11.5, color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                                side: const BorderSide(color: Color(0xFFEF4444)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 18),

                    // Faculty Search & Selection Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select Faculty Member',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : const Color(0xFF334155)),
                        ),
                        if (_selectedTeacherId != null)
                          TextButton.icon(
                            onPressed: () => setState(() => _selectedTeacherId = null),
                            icon: const Icon(Icons.person_off_outlined, size: 14, color: Color(0xFFEF4444)),
                            label: const Text('Unassign / Clear', style: TextStyle(fontSize: 11.5, color: Color(0xFFEF4444), fontWeight: FontWeight.w600)),
                            style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _searchController,
                      onChanged: (v) => _loadTeachers(query: v),
                      decoration: InputDecoration(
                        hintText: 'Search faculty from school by name, employee ID, or department...',
                        hintStyle: TextStyle(
                          color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                          fontSize: 12.5,
                        ),
                        prefixIcon: const Icon(Icons.search, size: 18),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  _loadTeachers(query: '');
                                },
                              )
                            : null,
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
                      ),
                      style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                    ),
                    const SizedBox(height: 10),

                    // Teacher List with Unassigned Option
                    Container(
                      height: 240,
                      decoration: BoxDecoration(
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                        borderRadius: BorderRadius.circular(8),
                        color: isDark ? const Color(0xFF0F172A).withOpacity(0.3) : Colors.white,
                      ),
                      child: _isLoadingTeachers
                          ? const Center(child: CircularProgressIndicator())
                          : ListView(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              children: [
                                // No Teacher / Unassign Tile
                                InkWell(
                                  onTap: () => setState(() => _selectedTeacherId = null),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                                    color: _selectedTeacherId == null
                                        ? (isDark ? const Color(0xFFEF4444).withOpacity(0.12) : const Color(0xFFFEF2F2))
                                        : Colors.transparent,
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(7),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEF4444).withOpacity(0.1),
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.person_off_outlined, size: 18, color: Color(0xFFEF4444)),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'No Teacher (Unassigned)',
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: _selectedTeacherId == null
                                                      ? const Color(0xFFDC2626)
                                                      : (isDark ? Colors.white : const Color(0xFF0F172A)),
                                                ),
                                              ),
                                              Text(
                                                'Keep this subject section unassigned without a teacher',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Radio<String?>(
                                          value: null,
                                          groupValue: _selectedTeacherId,
                                          activeColor: const Color(0xFFEF4444),
                                          onChanged: (_) => setState(() => _selectedTeacherId = null),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                Divider(
                                  height: 1,
                                  color: isDark ? const Color(0xFF334155).withOpacity(0.5) : const Color(0xFFE2E8F0),
                                ),

                                if (_teachers.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Center(
                                      child: Text(
                                        'No faculty found matching search.',
                                        style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                      ),
                                    ),
                                  )
                                else
                                  ..._teachers.map((t) {
                                    final isSelected = _selectedTeacherId == t.id;
                                    final isInitial = _initialTeacher?.id == t.id;

                                    return InkWell(
                                      onTap: () => setState(() => _selectedTeacherId = t.id),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        color: isSelected
                                            ? (isDark ? const Color(0xFF4F46E5).withOpacity(0.18) : const Color(0xFFEEF2FF))
                                            : Colors.transparent,
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 16,
                                              backgroundColor: isInitial
                                                  ? const Color(0xFF10B981).withOpacity(0.2)
                                                  : const Color(0xFF4F46E5).withOpacity(0.15),
                                              backgroundImage: t.avatarUrl != null ? NetworkImage(t.avatarUrl!) : null,
                                              child: t.avatarUrl == null
                                                  ? Text(
                                                      t.fullName.isNotEmpty ? t.fullName[0].toUpperCase() : 'T',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.w700,
                                                        color: isInitial ? const Color(0xFF059669) : const Color(0xFF4F46E5),
                                                      ),
                                                    )
                                                  : null,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Text(
                                                        t.fullName,
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight: FontWeight.w600,
                                                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                                                        ),
                                                      ),
                                                      if (isInitial) ...[
                                                        const SizedBox(width: 6),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFF10B981).withOpacity(0.15),
                                                            borderRadius: BorderRadius.circular(3),
                                                          ),
                                                          child: const Text(
                                                            'ASSIGNED',
                                                            style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                                                          ),
                                                        ),
                                                      ],
                                                    ],
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
                                  }),
                              ],
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
                  Row(
                    children: [
                      Icon(
                        _selectedTeacherId != null
                            ? Icons.check_circle_rounded
                            : (hasInitialTeacher ? Icons.warning_amber_rounded : Icons.info_outline),
                        size: 16,
                        color: _selectedTeacherId != null
                            ? const Color(0xFF10B981)
                            : (hasInitialTeacher ? const Color(0xFFEF4444) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _selectedTeacherId != null
                            ? (_selectedTeacherId == _initialTeacher?.id ? 'Current Teacher Kept' : 'New Teacher Selected')
                            : (hasInitialTeacher ? 'Will Be Unassigned' : 'No Teacher Selected'),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _selectedTeacherId != null
                              ? const Color(0xFF10B981)
                              : (hasInitialTeacher ? const Color(0xFFEF4444) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B))),
                        ),
                      ),
                    ],
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
                          backgroundColor: isUnassignSelected ? const Color(0xFFEF4444) : const Color(0xFF4F46E5),
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
                                isUnassignSelected ? 'Confirm Unassign' : 'Save Assignment',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
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
