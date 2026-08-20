import 'package:flutter/material.dart';
import '../../models/class_models.dart';
import '../../services/academic_lookup_helper.dart';
import '../../services/class_api_service.dart';

class CreateEditSectionDialog extends StatefulWidget {
  final AcademicSectionModel? sectionToEdit;
  final String? defaultClassId;
  final List<AcademicClassModel> availableClasses;
  final List<AcademicRoomModel> availableRooms;
  final String academicYear;
  final Function(Map<String, dynamic> data) onSave;

  const CreateEditSectionDialog({
    super.key,
    this.sectionToEdit,
    this.defaultClassId,
    this.availableClasses = const [],
    this.availableRooms = const [],
    this.academicYear = '2026-27',
    required this.onSave,
  });

  @override
  State<CreateEditSectionDialog> createState() => _CreateEditSectionDialogState();
}

class _CreateEditSectionDialogState extends State<CreateEditSectionDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _codeController;

  String? _selectedClassId;
  String? _selectedRoomId;
  String _status = 'ACTIVE';
  bool _isSaving = false;
  List<AcademicLookupItem> _statuses = [];
  List<AcademicRoomModel> _availableRooms = [];
  bool _isLoadingRooms = false;

  @override
  void initState() {
    super.initState();
    _availableRooms = List<AcademicRoomModel>.from(widget.availableRooms);

    final s = widget.sectionToEdit;
    if (s != null) {
      _selectedClassId = s.classId;
      _nameController = TextEditingController(text: s.name);
      _codeController = TextEditingController(text: s.code);
      _status = s.status;
      _selectedRoomId = s.roomId;
      if (_selectedRoomId == null && (s.roomNumber != null || s.roomName != null)) {
        final match = _availableRooms.where((r) =>
            r.name == (s.roomNumber ?? s.roomName) ||
            r.code == (s.roomNumber ?? s.roomName)).firstOrNull;
        _selectedRoomId = match?.id;
      }
    } else {
      _selectedClassId = widget.defaultClassId ?? (widget.availableClasses.isNotEmpty ? widget.availableClasses.first.id : null);
      _nameController = TextEditingController();
      _codeController = TextEditingController();
      _status = 'ACTIVE';
    }
    _loadLookups();
  }

  Future<void> _loadLookups() async {
    // 1. If rooms list was passed empty (e.g. opened directly from Sections tab), fetch all rooms dynamically
    if (_availableRooms.isEmpty) {
      _isLoadingRooms = true;
      try {
        final res = await ClassApiService().getRooms(pageSize: 100);
        final List<AcademicRoomModel> fetched = res['rooms'] ?? [];
        if (mounted && fetched.isNotEmpty) {
          setState(() {
            _availableRooms = fetched;
            final s = widget.sectionToEdit;
            if (_selectedRoomId == null && s != null && (s.roomNumber != null || s.roomName != null)) {
              final match = _availableRooms.where((r) =>
                  r.name == (s.roomNumber ?? s.roomName) ||
                  r.code == (s.roomNumber ?? s.roomName)).firstOrNull;
              _selectedRoomId = match?.id;
            }
          });
        }
      } catch (_) {
      } finally {
        if (mounted) setState(() => _isLoadingRooms = false);
      }
    }

    // 2. Load active lookup items for status
    final list = await AcademicLookupHelper.instance.getActiveLookup('ACADEMIC_STATUS');
    if (mounted) {
      setState(() {
        _statuses = List<AcademicLookupItem>.from(list);
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
    super.dispose();
  }

  void _onRoomSelected(String? roomId) {
    setState(() {
      _selectedRoomId = roomId;
    });
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClassId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an Academic Class')),
      );
      return;
    }

    final selectedClass = widget.availableClasses.where((c) => c.id == _selectedClassId).firstOrNull;
    if (_status.toUpperCase() == 'ACTIVE' && selectedClass != null && selectedClass.status.toUpperCase() != 'ACTIVE') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Cannot activate Section. The parent Class "${selectedClass.name}" is currently Inactive. Please activate the Class first.',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    final selectedRoom = _availableRooms.where((r) => r.id == _selectedRoomId).firstOrNull;
    final derivedCapacity = selectedRoom?.capacity ?? widget.sectionToEdit?.capacity ?? 40;
    final derivedRoomName = selectedRoom?.name ?? widget.sectionToEdit?.roomNumber;

    final payload = {
      'class_id': _selectedClassId,
      'name': _nameController.text.trim(),
      'code': _codeController.text.trim().toUpperCase(),
      'capacity': derivedCapacity,
      'room_number': derivedRoomName,
      'room_id': _selectedRoomId,
      'status': _status,
      'academic_year': widget.academicYear,
    };

    try {
      final dynamic res = await widget.onSave(payload);
      if (res == false) {
        if (mounted) setState(() => _isSaving = false);
        return;
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.sectionToEdit != null;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final selectedRoom = _availableRooms.where((r) => r.id == _selectedRoomId).firstOrNull;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        width: 540,
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
                    child: const Icon(Icons.grid_view_rounded, color: Color(0xFF10B981), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit ? 'Edit Section' : 'Add Section',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isEdit
                              ? 'Update section details, room assignment and capacity.'
                              : 'Configure section name, capacity, and classroom room allocation.',
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
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ],
              ),
            ),

            // Form Body
            Flexible(
              child: Form(
                key: _formKey,
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(24),
                  children: [
                    // Academic Class Picker
                    _buildFieldLabel('Academic Class *', isDark),
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
                          value: _selectedClassId,
                          isExpanded: true,
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 14),
                          hint: const Text('Select Academic Class'),
                          items: widget.availableClasses.map((c) {
                            return DropdownMenuItem(
                              value: c.id,
                              child: Text('${c.name} (${c.code})'),
                            );
                          }).toList(),
                          onChanged: isEdit ? null : (v) => setState(() => _selectedClassId = v),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Section Name & Code
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildFieldLabel('Section Name *', isDark),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _nameController,
                                decoration: _inputDecoration('e.g. 9-A or A', isDark),
                                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 14),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                                onChanged: (v) {
                                  if (!isEdit && _codeController.text.isEmpty) {
                                    _codeController.text = v.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').toUpperCase();
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
                              _buildFieldLabel('Section Code *', isDark),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: _codeController,
                                decoration: _inputDecoration('e.g. 9A or A', isDark),
                                style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 14),
                                validator: (v) => (v == null || v.trim().isEmpty) ? 'Code is required' : null,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Assigned Room (Dropdown from Academic Rooms)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildFieldLabel('Allocated Classroom (Room)', isDark),
                        if (_isLoadingRooms)
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                        borderRadius: BorderRadius.circular(8),
                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String?>(
                          value: _availableRooms.any((r) => r.id == _selectedRoomId) ? _selectedRoomId : null,
                          isExpanded: true,
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 14),
                          hint: Text(_isLoadingRooms ? 'Loading rooms...' : 'Select Allocated Room (Optional)'),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('No Room Linked (Default 40 seats)'),
                            ),
                            ..._availableRooms.map((r) {
                              return DropdownMenuItem<String?>(
                                value: r.id,
                                child: Text('${r.name} (${r.code}) • ${r.building} [Cap: ${r.capacity}]'),
                              );
                            }),
                          ],
                          onChanged: _onRoomSelected,
                        ),
                      ),
                    ),

                    // Dynamic Room Info Badge
                    if (selectedRoom != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.meeting_room_rounded, color: Color(0xFF10B981), size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${selectedRoom.name} (${selectedRoom.code})',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${selectedRoom.building} • ${selectedRoom.floor} • Capacity: ${selectedRoom.capacity} seats',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),

                    // Status
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
                          value: _statuses.any((s) => s.code == _status)
                              ? _status
                              : (_statuses.isNotEmpty ? _statuses.first.code : 'ACTIVE'),
                          isExpanded: true,
                          dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          style: TextStyle(color: isDark ? Colors.white : const Color(0xFF0F172A), fontSize: 14),
                          items: _statuses
                              .map((s) => DropdownMenuItem(value: s.code, child: Text(s.label)))
                              .toList(),
                          onChanged: (v) => setState(() => _status = v ?? 'ACTIVE'),
                        ),
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
                        : Text(
                            isEdit ? 'Save Changes' : 'Add Section',
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
        borderSide: const BorderSide(color: Color(0xFF10B981), width: 1.5),
      ),
    );
  }
}
