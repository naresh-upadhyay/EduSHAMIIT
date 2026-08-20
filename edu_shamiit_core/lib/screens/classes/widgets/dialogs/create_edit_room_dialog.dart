import 'package:flutter/material.dart';
import '../../models/class_models.dart';
import '../../services/academic_lookup_helper.dart';

class CreateEditRoomDialog extends StatefulWidget {
  final AcademicRoomModel? existingRoom;
  final List<String> availableBuildings;
  final List<String> availableFloors;
  final Future<bool> Function(Map<String, dynamic> payload) onSave;

  const CreateEditRoomDialog({
    super.key,
    this.existingRoom,
    this.availableBuildings = const [],
    this.availableFloors = const [],
    required this.onSave,
  });

  @override
  State<CreateEditRoomDialog> createState() => _CreateEditRoomDialogState();
}

class _CreateEditRoomDialogState extends State<CreateEditRoomDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _codeController;
  late TextEditingController _capacityController;
  late TextEditingController _descriptionController;

  late String _selectedType;
  late String _selectedBuilding;
  late String _selectedFloor;
  late String _selectedStatus;
  late List<String> _selectedFacilities;
  bool _isSaving = false;
  String? _errorMessage;

  List<AcademicLookupItem> _roomTypes = [];
  List<AcademicLookupItem> _roomStatuses = [];
  List<AcademicLookupItem> _buildings = [];
  List<AcademicLookupItem> _floors = [];
  List<AcademicLookupItem> _facilities = [];
  bool _isLoadingLookups = true;

  @override
  void initState() {
    super.initState();
    final room = widget.existingRoom;
    _nameController = TextEditingController(text: room?.name ?? '');
    _codeController = TextEditingController(text: room?.code ?? '');
    _capacityController = TextEditingController(text: (room?.capacity ?? 40).toString());
    _descriptionController = TextEditingController(text: room?.description ?? '');

    _selectedType = room?.type ?? 'Classroom';
    _selectedBuilding = room?.building ?? (widget.availableBuildings.isNotEmpty ? widget.availableBuildings.first : 'Academic Block A');
    _selectedFloor = room?.floor ?? (widget.availableFloors.isNotEmpty ? widget.availableFloors.first : 'Ground Floor');
    _selectedStatus = room?.status ?? 'AVAILABLE';
    _selectedFacilities = List<String>.from(room?.facilities ?? []);
    _loadDynamicLookups();
  }

  Future<void> _loadDynamicLookups() async {
    final lookupHelper = AcademicLookupHelper.instance;
    final results = await Future.wait([
      lookupHelper.getActiveLookup('ROOM_TYPE'),
      lookupHelper.getActiveLookup('ROOM_STATUS'),
      lookupHelper.getActiveLookup('CAMPUS_BUILDING'),
      lookupHelper.getActiveLookup('BUILDING_FLOOR'),
      lookupHelper.getActiveLookup('ROOM_FACILITY'),
    ]);

    if (mounted) {
      setState(() {
        _roomTypes = List<AcademicLookupItem>.from(results[0]);
        _roomStatuses = List<AcademicLookupItem>.from(results[1]);
        _buildings = List<AcademicLookupItem>.from(results[2]);
        _floors = List<AcademicLookupItem>.from(results[3]);

        // Merge loaded active facilities with any existing room facilities so none are missed
        final loadedFacilities = List<AcademicLookupItem>.from(results[4]);
        for (final fac in _selectedFacilities) {
          if (!loadedFacilities.any((item) => item.label.toLowerCase() == fac.toLowerCase())) {
            loadedFacilities.add(AcademicLookupItem(
              id: fac,
              code: fac.toUpperCase().replaceAll(' ', '_'),
              label: fac,
            ));
          }
        }
        _facilities = loadedFacilities;
        _isLoadingLookups = false;

        // Dynamic status match without dropping custom statuses
        if (_selectedStatus.isNotEmpty) {
          final matchedStatus = _roomStatuses.where((s) =>
              s.code.toUpperCase() == _selectedStatus.toUpperCase() ||
              s.label.toUpperCase() == _selectedStatus.toUpperCase()).firstOrNull;
          if (matchedStatus != null) {
            _selectedStatus = matchedStatus.code;
          } else {
            _roomStatuses.add(AcademicLookupItem(
              id: _selectedStatus,
              code: _selectedStatus,
              label: _selectedStatus,
            ));
          }
        }

        // Verify and align selections with loaded active lookups
        if (_roomTypes.isNotEmpty && !_roomTypes.any((t) => t.label.toLowerCase() == _selectedType.toLowerCase() || t.code.toLowerCase() == _selectedType.toLowerCase())) {
          _selectedType = _roomTypes.first.label;
        }

        if (_buildings.isNotEmpty && !_buildings.any((b) => b.label == _selectedBuilding || b.code == _selectedBuilding)) {
          _selectedBuilding = _buildings.first.label;
        }

        if (_floors.isNotEmpty && !_floors.any((f) => f.label == _selectedFloor || f.code == _selectedFloor)) {
          _selectedFloor = _floors.first.label;
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _capacityController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _generateCodeFromName(String name) {
    if (widget.existingRoom == null && _codeController.text.trim().isEmpty) {
      final code = name
          .replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '')
          .split(' ')
          .map((s) => s.isNotEmpty ? s[0].toUpperCase() : '')
          .join();
      if (code.isNotEmpty) {
        _codeController.text = code;
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final cap = int.tryParse(_capacityController.text.trim()) ?? 40;
    if (cap <= 0) {
      setState(() => _errorMessage = 'Capacity must be at least 1 seat.');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final payload = {
      'name': _nameController.text.trim(),
      'code': _codeController.text.trim().toUpperCase(),
      'type': _selectedType,
      'building': _selectedBuilding,
      'floor': _selectedFloor,
      'capacity': cap,
      'facilities': _selectedFacilities,
      'status': _selectedStatus,
      'description': _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
    };

    final ok = await widget.onSave(payload);
    if (mounted) {
      setState(() => _isSaving = false);
      if (ok) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEditing = widget.existingRoom != null;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        width: 580,
        constraints: const BoxConstraints(maxHeight: 700),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4F46E5).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.meeting_room_rounded,
                          color: Color(0xFF4F46E5),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'Edit Room / Facility' : 'Add New Room / Facility',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            isEditing ? 'Update room capacity and equipment' : 'Configure room details and facilities',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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
                      if (_errorMessage != null) ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E8),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFF87171)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(color: Color(0xFFDC2626), fontSize: 12.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Name & Code
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Room Name *', isDark),
                                TextFormField(
                                  controller: _nameController,
                                  decoration: _inputDecoration('e.g. Physics Lab, Room 101', isDark),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                                  onChanged: _generateCodeFromName,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Room Code *', isDark),
                                TextFormField(
                                  controller: _codeController,
                                  decoration: _inputDecoration('e.g. PHY-LAB-01', isDark),
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Dynamic Type & Dynamic Status Dropdowns
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Room Type', isDark),
                                Container(
                                  height: 44,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _roomTypes.any((t) => t.label.toLowerCase() == _selectedType.toLowerCase())
                                          ? _roomTypes.firstWhere((t) => t.label.toLowerCase() == _selectedType.toLowerCase()).label
                                          : (_roomTypes.isNotEmpty ? _roomTypes.first.label : _selectedType),
                                      isExpanded: true,
                                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                      items: _roomTypes.map((t) => DropdownMenuItem(value: t.label, child: Text(t.label))).toList(),
                                      onChanged: (v) {
                                        if (v != null) setState(() => _selectedType = v);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Operational Status', isDark),
                                Container(
                                  height: 44,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _roomStatuses.any((s) => s.code == _selectedStatus)
                                          ? _selectedStatus
                                          : (_roomStatuses.isNotEmpty ? _roomStatuses.first.code : 'AVAILABLE'),
                                      isExpanded: true,
                                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                      items: _roomStatuses
                                          .map((s) => DropdownMenuItem(value: s.code, child: Text(s.label)))
                                          .toList(),
                                      onChanged: (v) {
                                        if (v != null) setState(() => _selectedStatus = v);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Building, Floor & Capacity
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Building', isDark),
                                Container(
                                  height: 44,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _buildings.any((b) => b.label == _selectedBuilding)
                                          ? _selectedBuilding
                                          : (_buildings.isNotEmpty ? _buildings.first.label : _selectedBuilding),
                                      isExpanded: true,
                                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                      items: _buildings
                                          .map((b) => DropdownMenuItem(value: b.label, child: Text(b.label)))
                                          .toList(),
                                      onChanged: (v) {
                                        if (v != null) setState(() => _selectedBuilding = v);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Floor', isDark),
                                Container(
                                  height: 44,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _floors.any((f) => f.label == _selectedFloor)
                                          ? _selectedFloor
                                          : (_floors.isNotEmpty ? _floors.first.label : _selectedFloor),
                                      isExpanded: true,
                                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                      items: _floors
                                          .map((f) => DropdownMenuItem(value: f.label, child: Text(f.label)))
                                          .toList(),
                                      onChanged: (v) {
                                        if (v != null) setState(() => _selectedFloor = v);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Capacity *', isDark),
                                TextFormField(
                                  controller: _capacityController,
                                  keyboardType: TextInputType.number,
                                  decoration: _inputDecoration('e.g. 40', isDark),
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) return 'Required';
                                    final n = int.tryParse(v.trim());
                                    if (n == null || n <= 0) return 'Invalid';
                                    return null;
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Dynamic Equipped Facilities & Features (Active Lookups)
                      _buildLabel('Equipped Facilities & Features', isDark),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _facilities.map((facItem) {
                          final fac = facItem.label;
                          final isSelected = _selectedFacilities.any((f) => f.toLowerCase() == fac.toLowerCase());
                          return InkWell(
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedFacilities.removeWhere((f) => f.toLowerCase() == fac.toLowerCase());
                                } else {
                                  _selectedFacilities.add(fac);
                                }
                              });
                            },
                            borderRadius: BorderRadius.circular(6),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF4F46E5).withOpacity(0.12)
                                    : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF4F46E5)
                                      : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isSelected) ...[
                                    const Icon(Icons.check, size: 13, color: Color(0xFF4F46E5)),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    fac,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      color: isSelected
                                          ? const Color(0xFF4F46E5)
                                          : (isDark ? Colors.white70 : const Color(0xFF475569)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Description / Equipment Notes
                      _buildLabel('Description / Equipment Notes', isDark),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: _inputDecoration('Additional notes regarding room equipment, availability, or setup...', isDark),
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
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                      side: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(color: isDark ? Colors.white70 : const Color(0xFF475569)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(isEditing ? 'Save Changes' : 'Create Room'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String label, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        fontSize: 12.5,
        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
      ),
      filled: true,
      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
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
