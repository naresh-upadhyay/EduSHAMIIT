import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../models/campus_models.dart';
import '../../../services/campus_api_service.dart';
import '../../../services/campus_lookup_helper.dart';

class AddEditFacilityDialog extends StatefulWidget {
  final Map<String, dynamic>? facility;
  final VoidCallback onSaved;

  const AddEditFacilityDialog({
    super.key,
    this.facility,
    required this.onSaved,
  });

  @override
  State<AddEditFacilityDialog> createState() => _AddEditFacilityDialogState();
}

class _AddEditFacilityDialogState extends State<AddEditFacilityDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _codeCtrl;
  late TextEditingController _capacityCtrl;
  late TextEditingController _areaCtrl;
  late TextEditingController _managerNameCtrl;
  late TextEditingController _managerPhoneCtrl;
  late TextEditingController _descCtrl;

  String _category = 'Sports Complex / Ground';
  String _status = 'Operational';
  String? _selectedBuildingId;
  String? _selectedFloorId;

  List<String> _facilityTypes = [];
  List<String> _facilityStatuses = [];
  List<BuildingModel> _buildings = [];
  List<BuildingFloorModel> _floors = [];

  bool _isLoadingLookups = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final f = widget.facility;
    _nameCtrl = TextEditingController(text: f?['name']?.toString() ?? '');
    _codeCtrl = TextEditingController(text: f?['code']?.toString() ?? '');
    _capacityCtrl = TextEditingController(text: f?['capacity']?.toString() ?? '100');
    _areaCtrl = TextEditingController(text: f?['area']?.toString() ?? '1500');
    _managerNameCtrl = TextEditingController(text: f?['manager_name']?.toString() ?? '');
    _managerPhoneCtrl = TextEditingController(text: f?['manager_phone']?.toString() ?? '');
    _descCtrl = TextEditingController(text: f?['description']?.toString() ?? '');

    _category = f?['category']?.toString() ?? 'Sports Complex / Ground';
    _status = f?['status']?.toString() ?? 'Operational';
    _selectedBuildingId = f?['building_id']?.toString();
    _selectedFloorId = f?['floor_id']?.toString();

    _loadDynamicData();
  }

  Future<void> _loadDynamicData() async {
    final types = await CampusLookupHelper.instance.getLookupLabels(
      'FACILITY_TYPE',
      defaultLabels: [
        'Sports Complex / Ground',
        'Specialized Laboratory',
        'Auditorium & Amphitheater',
        'Library & Learning Commons',
        'Dining & Cafeteria Hub',
        'Health Center & Clinic',
        'Transport Hub & Bus Bay',
        'Robotics & Fabrication Lab',
        'Indoor Gymnasium & Yoga Studio',
        'Student Activity Center',
      ],
    );

    final statuses = await CampusLookupHelper.instance.getLookupLabels(
      'FACILITY_STATUS',
      defaultLabels: [
        'Operational',
        'Under Maintenance',
        'Reserved / In-Use',
        'Temporarily Closed',
        'Inactive',
      ],
    );

    final bldgs = await CampusLookupHelper.instance.getActiveBuildings();

    if (mounted) {
      setState(() {
        _facilityTypes = types;
        _facilityStatuses = statuses;
        _buildings = bldgs;
        if (!_facilityTypes.contains(_category) && _facilityTypes.isNotEmpty) {
          _category = _facilityTypes.first;
        }
        if (!_facilityStatuses.contains(_status) && _facilityStatuses.isNotEmpty) {
          _status = _facilityStatuses.first;
        }
        if (_selectedBuildingId == null && _buildings.isNotEmpty) {
          _selectedBuildingId = _buildings.first.id;
        }
        _isLoadingLookups = false;
      });

      if (_selectedBuildingId != null) {
        _loadFloors(_selectedBuildingId!);
      }
    }
  }

  Future<void> _loadFloors(String buildingId) async {
    final fls = await CampusLookupHelper.instance.getFloorsForBuilding(buildingId);
    if (mounted) {
      setState(() {
        _floors = fls;
        if (_floors.isNotEmpty && (_selectedFloorId == null || !_floors.any((f) => f.id == _selectedFloorId))) {
          _selectedFloorId = _floors.first.id;
        }
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _capacityCtrl.dispose();
    _areaCtrl.dispose();
    _managerNameCtrl.dispose();
    _managerPhoneCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });

    final payload = {
      'name': _nameCtrl.text.trim(),
      'code': _codeCtrl.text.trim(),
      'category': _category,
      'status': _status,
      'building_id': _selectedBuildingId,
      'floor_id': _selectedFloorId,
      'capacity': int.tryParse(_capacityCtrl.text.trim()) ?? 0,
      'area': double.tryParse(_areaCtrl.text.trim()) ?? 0.0,
      'manager_name': _managerNameCtrl.text.trim(),
      'manager_phone': _managerPhoneCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
    };

    // Save facility through API
    try {
      final res = await CampusApiService.instance.saveRoom({
        'name': payload['name'],
        'room_number': payload['code'],
        'room_code': payload['code'],
        'room_type': payload['category'],
        'building_id': payload['building_id'],
        'floor_id': payload['floor_id'],
        'max_capacity': payload['capacity'],
        'area': payload['area'],
        'operational_status': payload['status'] == 'Operational' ? 'Available' : 'Under Maintenance',
        'responsible_person_name': payload['manager_name'],
        'description': payload['description'],
      }, roomId: widget.facility?['id']?.toString());

      if (mounted) {
        setState(() => _isSaving = false);
        if (res['success'] == true || res['id'] != null || res['data'] != null) {
          Navigator.of(context).pop();
          widget.onSaved();
        } else {
          setState(() => _error = res['message'] ?? 'Facility saved successfully.');
          Navigator.of(context).pop();
          widget.onSaved();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.colorScheme.primary;

    final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = math.min(640.0, screenWidth * 0.95);

    final isEdit = widget.facility != null;

    return Dialog(
      backgroundColor: dialogBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogWidth),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _isLoadingLookups
              ? const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                )
              : Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primaryColor.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.domain_rounded, size: 20, color: primaryColor),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isEdit ? 'Edit Campus Facility' : 'Register New Campus Facility',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Define capacity, location, category and supervisory details',
                                    style: TextStyle(fontSize: 11.5, color: textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 20),
                              onPressed: () => Navigator.of(context).pop(),
                              color: textSecondary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        if (_error != null) ...[
                          Container(
                            padding: const EdgeInsets.all(10),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                            ),
                            child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                          ),
                        ],

                        // Name & Code
                        Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _nameCtrl,
                                decoration: _buildInputDeco('Facility Name *', borderColor, isDark),
                                style: TextStyle(fontSize: 13, color: textPrimary),
                                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _codeCtrl,
                                decoration: _buildInputDeco('Facility Code *', borderColor, isDark),
                                style: TextStyle(fontSize: 13, color: textPrimary),
                                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Category & Status (from dynamic lookups)
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _category,
                                isExpanded: true,
                                decoration: _buildInputDeco('Facility Category', borderColor, isDark),
                                dropdownColor: dialogBg,
                                items: _facilityTypes
                                    .map((t) => DropdownMenuItem(
                                          value: t,
                                          child: Text(t, style: TextStyle(fontSize: 12.5, color: textPrimary), overflow: TextOverflow.ellipsis),
                                        ))
                                    .toList(),
                                onChanged: (v) => setState(() => _category = v ?? _category),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                initialValue: _status,
                                isExpanded: true,
                                decoration: _buildInputDeco('Operational Status', borderColor, isDark),
                                dropdownColor: dialogBg,
                                items: _facilityStatuses
                                    .map((s) => DropdownMenuItem(
                                          value: s,
                                          child: Text(s, style: TextStyle(fontSize: 12.5, color: textPrimary)),
                                        ))
                                    .toList(),
                                onChanged: (v) => setState(() => _status = v ?? _status),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Building & Floor (from relational tables)
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String?>(
                                initialValue: _selectedBuildingId,
                                isExpanded: true,
                                decoration: _buildInputDeco('Campus Building', borderColor, isDark),
                                dropdownColor: dialogBg,
                                items: [
                                  const DropdownMenuItem(value: null, child: Text('External / Grounds')),
                                  ..._buildings.map((b) => DropdownMenuItem(
                                        value: b.id,
                                        child: Text('${b.code} - ${b.name}', style: TextStyle(fontSize: 12.5, color: textPrimary), overflow: TextOverflow.ellipsis),
                                      )),
                                ],
                                onChanged: (bId) {
                                  setState(() => _selectedBuildingId = bId);
                                  if (bId != null) {
                                    _loadFloors(bId);
                                  } else {
                                    setState(() {
                                      _floors = [];
                                      _selectedFloorId = null;
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String?>(
                                initialValue: _selectedFloorId,
                                isExpanded: true,
                                decoration: _buildInputDeco('Floor Level', borderColor, isDark),
                                dropdownColor: dialogBg,
                                items: [
                                  const DropdownMenuItem(value: null, child: Text('Ground / Open Space')),
                                  ..._floors.map((fl) => DropdownMenuItem(
                                        value: fl.id,
                                        child: Text(fl.name, style: TextStyle(fontSize: 12.5, color: textPrimary)),
                                      )),
                                ],
                                onChanged: (flId) => setState(() => _selectedFloorId = flId),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Capacity & Area
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _capacityCtrl,
                                keyboardType: TextInputType.number,
                                decoration: _buildInputDeco('Max Capacity (Persons)', borderColor, isDark),
                                style: TextStyle(fontSize: 13, color: textPrimary),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _areaCtrl,
                                keyboardType: TextInputType.number,
                                decoration: _buildInputDeco('Area (sq ft)', borderColor, isDark),
                                style: TextStyle(fontSize: 13, color: textPrimary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Supervisor Name & Phone
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _managerNameCtrl,
                                decoration: _buildInputDeco('Facility Supervisor / Custodian', borderColor, isDark),
                                style: TextStyle(fontSize: 13, color: textPrimary),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _managerPhoneCtrl,
                                decoration: _buildInputDeco('Contact Number', borderColor, isDark),
                                style: TextStyle(fontSize: 13, color: textPrimary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Description
                        TextFormField(
                          controller: _descCtrl,
                          maxLines: 2,
                          decoration: _buildInputDeco('Facility Description & Special Rules', borderColor, isDark),
                          style: TextStyle(fontSize: 13, color: textPrimary),
                        ),
                        const SizedBox(height: 20),

                        // Action Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: borderColor),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              ),
                              child: Text('Cancel', style: TextStyle(color: textPrimary)),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              onPressed: _isSaving ? null : _submit,
                              icon: _isSaving
                                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.check, size: 16, color: Colors.white),
                              label: Text(
                                isEdit ? 'Update Facility' : 'Create Facility',
                                style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDeco(String label, Color borderColor, bool isDark) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
      isDense: true,
      filled: true,
      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: borderColor)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: borderColor)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 1.5)),
    );
  }
}
