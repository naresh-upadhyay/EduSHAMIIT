import 'package:flutter/material.dart';
import '../../models/class_models.dart';
import '../../services/class_api_service.dart';
import 'student_move_warning_dialog.dart';

class AssignStudentsDialog extends StatefulWidget {
  final String classId;
  final String className;
  final String? sectionId;
  final String? sectionName;
  final String academicYear;
  final Function(List<String> studentIds, bool confirmMove) onSave;

  const AssignStudentsDialog({
    super.key,
    required this.classId,
    required this.className,
    this.sectionId,
    this.sectionName,
    this.academicYear = '2026-27',
    required this.onSave,
  });

  @override
  State<AssignStudentsDialog> createState() => _AssignStudentsDialogState();
}

class _AssignStudentsDialogState extends State<AssignStudentsDialog> {
  final ClassApiService _api = ClassApiService();
  final TextEditingController _searchController = TextEditingController();

  List<AcademicStudentModel> _students = [];
  final Set<String> _selectedStudentIds = {};
  bool _hasInitializedSelection = false;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadStudents({String query = ''}) async {
    setState(() => _isLoading = true);
    final results = await _api.searchStudents(
      search: query,
      academicYear: widget.academicYear,
      limit: 200,
    );
    if (mounted) {
      setState(() {
        _students = results;
        if (!_hasInitializedSelection) {
          _hasInitializedSelection = true;
          for (var s in results) {
            final isCurrentlyHere = widget.sectionId != null
                ? (s.currentSectionId == widget.sectionId)
                : (s.currentClassId == widget.classId && (s.currentSectionId == null || s.currentSectionId!.isEmpty));
            if (isCurrentlyHere) {
              _selectedStudentIds.add(s.id);
            }
          }
        }
        _isLoading = false;
      });
    }
  }

  void _selectAllFiltered() {
    setState(() {
      for (var s in _students) {
        _selectedStudentIds.add(s.id);
      }
    });
  }

  void _deselectAllFiltered() {
    setState(() {
      for (var s in _students) {
        _selectedStudentIds.remove(s.id);
      }
    });
  }

  void _validateAndSubmit() async {
    setState(() => _isSaving = true);
    final ids = _selectedStudentIds.toList();

    // Check conflict moves (excluding students already assigned to target)
    final conflicts = await _api.checkStudentMoves(
      studentIds: ids,
      academicYear: widget.academicYear,
      targetClassId: widget.classId,
      targetSectionId: widget.sectionId,
    );

    if (conflicts.isNotEmpty) {
      setState(() => _isSaving = false);
      if (!mounted) return;

      final targetLoc = widget.sectionName != null
          ? '${widget.className}-${widget.sectionName}'
          : widget.className;

      showDialog(
        context: context,
        builder: (ctx) => StudentMoveWarningDialog(
          conflicts: conflicts,
          targetLocation: targetLoc,
          onConfirmMove: () => _executeAssignment(ids, confirmMove: true),
        ),
      );
    } else {
      _executeAssignment(ids, confirmMove: false);
    }
  }

  void _executeAssignment(List<String> ids, {bool confirmMove = false}) async {
    setState(() => _isSaving = true);
    try {
      await widget.onSave(ids, confirmMove);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final targetLabel = widget.sectionName != null ? '${widget.className} - Section ${widget.sectionName}' : widget.className;

    final allFilteredSelected = _students.isNotEmpty && _students.every((s) => _selectedStudentIds.contains(s.id));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        width: 620,
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
                      color: const Color(0xFF10B981).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.group_add_rounded, color: Color(0xFF10B981), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Assign Students',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Select or reassign students for $targetLabel (${widget.academicYear}).',
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
                    icon: const Icon(Icons.close, size: 20),
                    splashRadius: 18,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ],
              ),
            ),

            // Search Bar & Bulk Selection Controls
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 10),
              child: Column(
                children: [
                  TextField(
                    controller: _searchController,
                    onChanged: (v) => _loadStudents(query: v),
                    decoration: InputDecoration(
                      hintText: 'Search student by name, admission no, or roll no...',
                      hintStyle: TextStyle(
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                _loadStudents(query: '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                      ),
                    ),
                    style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Showing ${_students.length} students',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: _students.isEmpty
                                ? null
                                : (allFilteredSelected ? _deselectAllFiltered : _selectAllFiltered),
                            icon: Icon(
                              allFilteredSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
                              size: 15,
                              color: const Color(0xFF10B981),
                            ),
                            label: Text(
                              allFilteredSelected ? 'Deselect All' : 'Select All Filtered',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF10B981),
                              ),
                            ),
                          ),
                          if (_selectedStudentIds.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            TextButton.icon(
                              onPressed: () => setState(() => _selectedStudentIds.clear()),
                              icon: const Icon(Icons.clear_all_rounded, size: 15, color: Color(0xFFEF4444)),
                              label: const Text(
                                'Clear All',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Students List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _students.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_search_outlined, size: 40, color: isDark ? const Color(0xFF64748B) : const Color(0xFFCBD5E1)),
                              const SizedBox(height: 12),
                              Text(
                                'No students found matching query.',
                                style: TextStyle(color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B), fontSize: 13),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                          shrinkWrap: true,
                          itemCount: _students.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: isDark ? const Color(0xFF334155).withOpacity(0.5) : const Color(0xFFE2E8F0),
                          ),
                          itemBuilder: (context, index) {
                            final s = _students[index];
                            final isSelected = _selectedStudentIds.contains(s.id);
                            final isCurrentlyHere = widget.sectionId != null
                                ? (s.currentSectionId == widget.sectionId)
                                : (s.currentClassId == widget.classId && (s.currentSectionId == null || s.currentSectionId!.isEmpty));

                            return InkWell(
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedStudentIds.remove(s.id);
                                  } else {
                                    _selectedStudentIds.add(s.id);
                                  }
                                });
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                margin: const EdgeInsets.symmetric(vertical: 2),
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? (isDark ? const Color(0xFF10B981).withOpacity(0.12) : const Color(0xFFECFDF5))
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: isCurrentlyHere
                                          ? const Color(0xFF10B981).withOpacity(0.18)
                                          : const Color(0xFF4F46E5).withOpacity(0.12),
                                      backgroundImage: s.avatarUrl != null ? NetworkImage(s.avatarUrl!) : null,
                                      child: s.avatarUrl == null
                                          ? Text(
                                              s.fullName.isNotEmpty ? s.fullName[0].toUpperCase() : 'S',
                                              style: TextStyle(
                                                color: isCurrentlyHere ? const Color(0xFF10B981) : const Color(0xFF4F46E5),
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                              ),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            s.fullName,
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Wrap(
                                            crossAxisAlignment: WrapCrossAlignment.center,
                                            spacing: 8,
                                            runSpacing: 4,
                                            children: [
                                              Text(
                                                '${s.admissionNumber ?? 'ADM'} • Roll: ${s.rollNumber ?? '-'}',
                                                style: TextStyle(
                                                  fontSize: 11.5,
                                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: isCurrentlyHere
                                                      ? const Color(0xFF10B981).withOpacity(0.15)
                                                      : (s.isAssigned
                                                          ? const Color(0xFFF59E0B).withOpacity(0.15)
                                                          : const Color(0xFF64748B).withOpacity(0.12)),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  isCurrentlyHere
                                                      ? 'Currently Assigned Here'
                                                      : (s.isAssigned ? s.assignmentSummary : 'Unassigned'),
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                    color: isCurrentlyHere
                                                      ? const Color(0xFF059669)
                                                      : (s.isAssigned ? const Color(0xFFD97706) : const Color(0xFF64748B)),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Checkbox(
                                      value: isSelected,
                                      activeColor: const Color(0xFF10B981),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                      onChanged: (val) {
                                        setState(() {
                                          if (val == true) {
                                            _selectedStudentIds.add(s.id);
                                          } else {
                                            _selectedStudentIds.remove(s.id);
                                          }
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
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
                    '${_selectedStudentIds.length} Students Selected',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _selectedStudentIds.isNotEmpty ? const Color(0xFF10B981) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
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
                        onPressed: _isSaving ? null : _validateAndSubmit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
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
                            : const Text('Save Assignments', style: TextStyle(fontWeight: FontWeight.w600)),
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
