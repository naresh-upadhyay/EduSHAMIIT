import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/campus_models.dart';
import '../../services/campus_api_service.dart';
import '../../services/campus_lookup_helper.dart';

class AddEditBuildingDialog extends StatefulWidget {
  final BuildingModel? building;
  final VoidCallback onSaved;

  const AddEditBuildingDialog({
    super.key,
    this.building,
    required this.onSaved,
  });

  @override
  State<AddEditBuildingDialog> createState() => _AddEditBuildingDialogState();
}

class _AddEditBuildingDialogState extends State<AddEditBuildingDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _codeCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _purposeCtrl;
  late TextEditingController _floorsCtrl;
  late TextEditingController _areaCtrl;
  late TextEditingController _yearCtrl;
  late TextEditingController _entrancesCtrl;
  late TextEditingController _exitsCtrl;
  late TextEditingController _managerNameCtrl;
  late TextEditingController _managerPhoneCtrl;
  late TextEditingController _deptCtrl;
  late TextEditingController _imageCtrl;

  String _buildingType = 'Academic';
  String _areaUnit = 'sq ft';
  String _status = 'Active';
  bool _isSaving = false;
  String? _error;

  List<String> _buildingTypes = [];
  List<String> _statuses = [];

  @override
  void initState() {
    super.initState();
    _buildingTypes = CampusLookupHelper.instance.getImmediateLabels('BUILDING_TYPE');
    _statuses = CampusLookupHelper.instance.getImmediateLabels('BUILDING_STATUS');
    _loadAsyncLookups();
    final b = widget.building;
    _nameCtrl = TextEditingController(text: b?.name ?? '');
    _codeCtrl = TextEditingController(text: b?.code ?? '');
    _descCtrl = TextEditingController(text: b?.description ?? '');
    _purposeCtrl = TextEditingController(text: b?.purpose ?? '');
    _floorsCtrl = TextEditingController(text: b != null ? '${b.totalFloors}' : '1');
    _areaCtrl = TextEditingController(text: b != null ? '${b.totalArea}' : '0.0');
    _yearCtrl = TextEditingController(text: b?.constructionYear != null ? '${b!.constructionYear}' : '2022');
    _entrancesCtrl = TextEditingController(text: b != null ? '${b.numEntrances}' : '1');
    _exitsCtrl = TextEditingController(text: b != null ? '${b.numEmergencyExits}' : '1');
    _managerNameCtrl = TextEditingController(text: b?.managerName ?? '');
    _managerPhoneCtrl = TextEditingController(text: b?.managerContact ?? '');
    _deptCtrl = TextEditingController(text: b?.department ?? '');
    _imageCtrl = TextEditingController(text: b?.imageUrl ?? '');

    if (b != null) {
      if (_buildingTypes.contains(b.buildingType)) _buildingType = b.buildingType;
      if (_statuses.contains(b.status)) _status = b.status;
      _areaUnit = b.areaUnit;
    }
  }

  Future<void> _loadAsyncLookups() async {
    final bTypes = await CampusLookupHelper.instance.getLookupLabels('BUILDING_TYPE');
    final stats = await CampusLookupHelper.instance.getLookupLabels('BUILDING_STATUS');
    await CampusLookupHelper.instance.getDepartments();
    if (mounted) {
      setState(() {
        _buildingTypes = bTypes;
        _statuses = stats;
        if (!_buildingTypes.contains(_buildingType) && _buildingTypes.isNotEmpty) {
          _buildingType = _buildingTypes.first;
        }
        if (!_statuses.contains(_status) && _statuses.isNotEmpty) {
          _status = _statuses.first;
        }
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _descCtrl.dispose();
    _purposeCtrl.dispose();
    _floorsCtrl.dispose();
    _areaCtrl.dispose();
    _yearCtrl.dispose();
    _entrancesCtrl.dispose();
    _exitsCtrl.dispose();
    _managerNameCtrl.dispose();
    _managerPhoneCtrl.dispose();
    _deptCtrl.dispose();
    _imageCtrl.dispose();
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
      'code': _codeCtrl.text.trim().toUpperCase(),
      'description': _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
      'purpose': _purposeCtrl.text.trim().isNotEmpty ? _purposeCtrl.text.trim() : null,
      'building_type': _buildingType,
      'total_floors': int.tryParse(_floorsCtrl.text) ?? 1,
      'total_area': double.tryParse(_areaCtrl.text) ?? 0.0,
      'area_unit': _areaUnit,
      'construction_year': int.tryParse(_yearCtrl.text),
      'num_entrances': int.tryParse(_entrancesCtrl.text) ?? 1,
      'num_emergency_exits': int.tryParse(_exitsCtrl.text) ?? 1,
      'status': _status,
      'manager_name': _managerNameCtrl.text.trim().isNotEmpty ? _managerNameCtrl.text.trim() : null,
      'manager_contact': _managerPhoneCtrl.text.trim().isNotEmpty ? _managerPhoneCtrl.text.trim() : null,
      'department': _deptCtrl.text.trim().isNotEmpty ? _deptCtrl.text.trim() : null,
      'image_url': _imageCtrl.text.trim().isNotEmpty ? _imageCtrl.text.trim() : null,
    };

    final res = await CampusApiService.instance.saveBuilding(
      payload,
      buildingId: widget.building?.id,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (res['success'] == true) {
        Navigator.of(context).pop();
        widget.onSaved();
      } else {
        setState(() => _error = res['message'] ?? 'Failed to save building.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.building != null;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final dialogWidth = math.min(600.0, screenWidth * 0.95);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(maxHeight: screenHeight * 0.9),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(isEdit ? Icons.edit_note_rounded : Icons.add_business_rounded, color: const Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isEdit ? 'Edit Building (${widget.building!.code})' : 'Add New Building',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 20),

            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),

            // Form Fields
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 500;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Basic Information
                          const Text('Basic Information', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF2563EB))),
                          const SizedBox(height: 10),

                          if (isCompact) ...[
                            TextFormField(
                              controller: _codeCtrl,
                              decoration: const InputDecoration(labelText: 'Building Code *', hintText: 'e.g. B1'),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Code is required' : null,
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _nameCtrl,
                              decoration: const InputDecoration(labelText: 'Building Name *', hintText: 'e.g. Academic Block'),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              initialValue: _buildingType,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Building Type'),
                              items: _buildingTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (v) => setState(() => _buildingType = v ?? _buildingType),
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              initialValue: _status,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Operational Status'),
                              items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (v) => setState(() => _status = v ?? _status),
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _codeCtrl,
                                    decoration: const InputDecoration(labelText: 'Building Code *', hintText: 'e.g. B1'),
                                    validator: (v) => v == null || v.trim().isEmpty ? 'Code is required' : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _nameCtrl,
                                    decoration: const InputDecoration(labelText: 'Building Name *', hintText: 'e.g. Academic Block'),
                                    validator: (v) => v == null || v.trim().isEmpty ? 'Name is required' : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _buildingType,
                                    isExpanded: true,
                                    decoration: const InputDecoration(labelText: 'Building Type'),
                                    items: _buildingTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
                                    onChanged: (v) => setState(() => _buildingType = v ?? _buildingType),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _status,
                                    isExpanded: true,
                                    decoration: const InputDecoration(labelText: 'Operational Status'),
                                    items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
                                    onChanged: (v) => setState(() => _status = v ?? _status),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _descCtrl,
                            maxLines: 2,
                            decoration: const InputDecoration(labelText: 'Description / Purpose', hintText: 'Brief summary of building contents & activities'),
                          ),
                          const SizedBox(height: 18),

                          // Physical Information
                          const Text('Physical Specifications', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF2563EB))),
                          const SizedBox(height: 10),

                          if (isCompact) ...[
                            TextFormField(
                              controller: _floorsCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Total Floors', hintText: '1'),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _areaCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Built-up Area', hintText: '45000'),
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              initialValue: _areaUnit,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Unit'),
                              items: const [
                                DropdownMenuItem(value: 'sq ft', child: Text('sq ft')),
                                DropdownMenuItem(value: 'sq m', child: Text('sq m')),
                              ],
                              onChanged: (v) => setState(() => _areaUnit = v ?? _areaUnit),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _yearCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Construction Year', hintText: '2020'),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _entrancesCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Entrances', hintText: '2'),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _exitsCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Emergency Exits', hintText: '2'),
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _floorsCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Total Floors', hintText: '1'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _areaCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(labelText: 'Built-up Area', hintText: '45000'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _areaUnit,
                                    isExpanded: true,
                                    decoration: const InputDecoration(labelText: 'Unit'),
                                    items: const [
                                      DropdownMenuItem(value: 'sq ft', child: Text('sq ft')),
                                      DropdownMenuItem(value: 'sq m', child: Text('sq m')),
                                    ],
                                    onChanged: (v) => setState(() => _areaUnit = v ?? _areaUnit),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _yearCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Construction Year', hintText: '2020'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _entrancesCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Entrances', hintText: '2'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _exitsCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Emergency Exits', hintText: '2'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 18),

                          // Management Information
                          const Text('Management & Incharge', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF2563EB))),
                          const SizedBox(height: 10),

                          if (isCompact) ...[
                            TextFormField(
                              controller: _managerNameCtrl,
                              decoration: const InputDecoration(labelText: 'Building Manager', hintText: 'e.g. Dr. Rajesh Sharma'),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _managerPhoneCtrl,
                              decoration: const InputDecoration(labelText: 'Manager Contact', hintText: '+91 98450 12345'),
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _managerNameCtrl,
                                    decoration: const InputDecoration(labelText: 'Building Manager', hintText: 'e.g. Dr. Rajesh Sharma'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _managerPhoneCtrl,
                                    decoration: const InputDecoration(labelText: 'Manager Contact', hintText: '+91 98450 12345'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _deptCtrl,
                            decoration: const InputDecoration(labelText: 'Responsible Department', hintText: 'e.g. Senior Secondary Wing'),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _imageCtrl,
                            decoration: const InputDecoration(labelText: 'Image URL', hintText: 'https://...'),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            const Divider(height: 20),

            // Footer Actions
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 10,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  child: _isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(isEdit ? 'Save Changes' : 'Create Building'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
