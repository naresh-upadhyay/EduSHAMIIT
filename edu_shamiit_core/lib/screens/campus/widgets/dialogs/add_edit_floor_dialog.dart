import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/campus_models.dart';
import '../../services/campus_api_service.dart';

class AddEditFloorDialog extends StatefulWidget {
  final String buildingId;
  final BuildingFloorModel? floor;
  final VoidCallback onSaved;

  const AddEditFloorDialog({
    super.key,
    required this.buildingId,
    this.floor,
    required this.onSaved,
  });

  @override
  State<AddEditFloorDialog> createState() => _AddEditFloorDialogState();
}

class _AddEditFloorDialogState extends State<AddEditFloorDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _codeCtrl;
  late TextEditingController _levelCtrl;
  late TextEditingController _orderCtrl;
  late TextEditingController _areaCtrl;
  late TextEditingController _descCtrl;

  String _floorType = 'Standard';
  String _status = 'Active';
  bool _isSaving = false;
  String? _error;

  static const List<String> floorTypes = [
    'Basement', 'Ground', 'Standard', 'Mezzanine', 'Rooftop', 'Service', 'Other'
  ];

  static const List<String> statuses = ['Active', 'Under Maintenance', 'Restricted', 'Closed'];

  @override
  void initState() {
    super.initState();
    final f = widget.floor;
    _nameCtrl = TextEditingController(text: f?.name ?? '');
    _codeCtrl = TextEditingController(text: f?.floorCode ?? '');
    _levelCtrl = TextEditingController(text: f != null ? '${f.floorLevel}' : '0');
    _orderCtrl = TextEditingController(text: f != null ? '${f.floorOrder}' : '0');
    _areaCtrl = TextEditingController(text: f != null ? '${f.area}' : '0.0');
    _descCtrl = TextEditingController(text: f?.description ?? '');

    if (f != null) {
      if (floorTypes.contains(f.floorType)) _floorType = f.floorType;
      if (statuses.contains(f.status)) _status = f.status;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _levelCtrl.dispose();
    _orderCtrl.dispose();
    _areaCtrl.dispose();
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
      'building_id': widget.buildingId,
      'name': _nameCtrl.text.trim(),
      'floor_code': _codeCtrl.text.trim(),
      'floor_level': int.tryParse(_levelCtrl.text) ?? 0,
      'floor_order': int.tryParse(_orderCtrl.text) ?? 0,
      'floor_type': _floorType,
      'area': double.tryParse(_areaCtrl.text) ?? 0.0,
      'description': _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
      'status': _status,
    };

    final res = await CampusApiService.instance.saveFloor(
      widget.buildingId,
      payload,
      floorId: widget.floor?.id,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (res['success'] == true) {
        Navigator.of(context).pop();
        widget.onSaved();
      } else {
        setState(() => _error = res['message'] ?? 'Failed to save floor.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.floor != null;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final dialogWidth = math.min(500.0, screenWidth * 0.95);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(maxHeight: screenHeight * 0.9),
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.layers_rounded, color: Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isEdit ? 'Edit Floor' : 'Add New Floor',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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
            const Divider(height: 16),

            if (_error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),

            Flexible(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 450;

                      return Column(
                        children: [
                          if (isCompact) ...[
                            TextFormField(
                              controller: _codeCtrl,
                              decoration: const InputDecoration(labelText: 'Floor Code *', hintText: 'e.g. G, F1, B1'),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _nameCtrl,
                              decoration: const InputDecoration(labelText: 'Floor Name *', hintText: 'e.g. Ground Floor (G)'),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _levelCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Floor Level *', hintText: '0 for Ground, -1 for B1'),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _areaCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Floor Area (sq ft)', hintText: '9000'),
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              initialValue: _floorType,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Floor Type'),
                              items: floorTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (v) => setState(() => _floorType = v ?? _floorType),
                            ),
                            const SizedBox(height: 10),
                            DropdownButtonFormField<String>(
                              initialValue: _status,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Status'),
                              items: statuses.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (v) => setState(() => _status = v ?? _status),
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _codeCtrl,
                                    decoration: const InputDecoration(labelText: 'Floor Code *', hintText: 'e.g. G, F1, B1'),
                                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    controller: _nameCtrl,
                                    decoration: const InputDecoration(labelText: 'Floor Name *', hintText: 'e.g. Ground Floor (G)'),
                                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _levelCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Floor Level *', hintText: '0 for Ground, -1 for B1'),
                                    validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _areaCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(labelText: 'Floor Area (sq ft)', hintText: '9000'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _floorType,
                                    isExpanded: true,
                                    decoration: const InputDecoration(labelText: 'Floor Type'),
                                    items: floorTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis))).toList(),
                                    onChanged: (v) => setState(() => _floorType = v ?? _floorType),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: _status,
                                    isExpanded: true,
                                    decoration: const InputDecoration(labelText: 'Status'),
                                    items: statuses.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis))).toList(),
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
                            decoration: const InputDecoration(labelText: 'Description', hintText: 'Evacuation corridors, primary usages'),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

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
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(isEdit ? 'Save Changes' : 'Create Floor'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
