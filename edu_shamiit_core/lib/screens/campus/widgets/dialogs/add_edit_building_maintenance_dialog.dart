import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/campus_models.dart';
import '../../services/campus_api_service.dart';
import '../../services/campus_lookup_helper.dart';

class AddEditBuildingMaintenanceDialog extends StatefulWidget {
  final BuildingModel building;
  final List<BuildingFloorModel> floors;
  final List<RoomModel> rooms;
  final BuildingMaintenanceModel? maintenance;
  final VoidCallback onSaved;

  const AddEditBuildingMaintenanceDialog({
    super.key,
    required this.building,
    required this.floors,
    required this.rooms,
    this.maintenance,
    required this.onSaved,
  });

  @override
  State<AddEditBuildingMaintenanceDialog> createState() => _AddEditBuildingMaintenanceDialogState();
}

class _AddEditBuildingMaintenanceDialogState extends State<AddEditBuildingMaintenanceDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _reporterCtrl;
  late TextEditingController _assignedCtrl;
  late TextEditingController _estCostCtrl;
  late TextEditingController _actCostCtrl;
  late TextEditingController _notesCtrl;

  String? _selectedFloorId;
  String? _selectedRoomId;
  String _requestType = 'Corrective';
  String _priority = 'Medium';
  String _status = 'Pending';
  DateTime? _preferredDate;

  bool _isSaving = false;
  String? _error;

  List<Map<String, dynamic>> _staffUsers = [];
  final _assignedFocusNode = FocusNode();
  final List<String> _requestTypes = [
    'Corrective', 'Preventive', 'Electrical', 'Plumbing', 'HVAC / AC',
    'Civil & Carpentry', 'IT & Smart Classroom', 'Painting & Cleaning', 'Fire Safety'
  ];
  final List<String> _priorities = ['Critical', 'High', 'Medium', 'Low'];
  final List<String> _statuses = ['Pending', 'In Progress', 'Completed', 'Cancelled'];

  @override
  void initState() {
    super.initState();
    final m = widget.maintenance;
    _titleCtrl = TextEditingController(text: m?.title ?? '');
    _descCtrl = TextEditingController(text: m?.description ?? '');
    _reporterCtrl = TextEditingController(text: m?.reportedByName ?? 'Campus Administrator');
    _assignedCtrl = TextEditingController(text: m?.assignedToName ?? '');
    _estCostCtrl = TextEditingController(text: m != null ? '${m.estimatedCost}' : '0.0');
    _actCostCtrl = TextEditingController(text: m != null ? '${m.actualCost}' : '0.0');
    _notesCtrl = TextEditingController(text: m?.resolutionNotes ?? '');

    _selectedFloorId = m?.floorId;
    _selectedRoomId = m?.roomId;
    if (m != null) {
      if (_requestTypes.contains(m.requestType)) _requestType = m.requestType;
      if (_priorities.contains(m.priority)) _priority = m.priority;
      if (_statuses.contains(m.status)) _status = m.status;
      if (m.preferredDate != null) _preferredDate = DateTime.tryParse(m.preferredDate!);
    }
    _loadStaffUsers();
  }

  Future<void> _loadStaffUsers() async {
    final users = await CampusLookupHelper.instance.getStaffUsers();
    if (mounted) {
      setState(() => _staffUsers = users);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _reporterCtrl.dispose();
    _assignedCtrl.dispose();
    _estCostCtrl.dispose();
    _actCostCtrl.dispose();
    _notesCtrl.dispose();
    _assignedFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _error = null;
    });

    // Derive location_display for clear referencing
    String locationDisplay = widget.building.name;
    if (_selectedRoomId != null) {
      final r = widget.rooms.firstWhere(
        (x) => x.id == _selectedRoomId,
        orElse: () => widget.rooms.first,
      );
      locationDisplay = '${widget.building.code} / ${r.roomNumber} (${r.name})';
    } else if (_selectedFloorId != null) {
      final f = widget.floors.firstWhere(
        (x) => x.id == _selectedFloorId,
        orElse: () => widget.floors.first,
      );
      locationDisplay = '${widget.building.code} / ${f.name}';
    } else {
      locationDisplay = '${widget.building.code} / Entire Building';
    }

    final payload = {
      'building_id': widget.building.id,
      'floor_id': _selectedFloorId,
      'room_id': _selectedRoomId,
      'location_display': locationDisplay,
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
      'request_type': _requestType,
      'priority': _priority,
      'status': _status,
      'reported_by_name': _reporterCtrl.text.trim().isNotEmpty ? _reporterCtrl.text.trim() : null,
      'assigned_to_name': _assignedCtrl.text.trim().isNotEmpty ? _assignedCtrl.text.trim() : null,
      'preferred_date': _preferredDate != null ? '${_preferredDate!.year}-${_preferredDate!.month.toString().padLeft(2, '0')}-${_preferredDate!.day.toString().padLeft(2, '0')}' : null,
      'estimated_cost': double.tryParse(_estCostCtrl.text) ?? 0.0,
      'actual_cost': double.tryParse(_actCostCtrl.text) ?? 0.0,
      'resolution_notes': _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
    };

    final res = await CampusApiService.instance.saveBuildingMaintenance(
      widget.building.id,
      payload,
      requestId: widget.maintenance?.id,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (res['success'] == true) {
        Navigator.of(context).pop();
        widget.onSaved();
      } else {
        setState(() => _error = res['message'] ?? 'Failed to save maintenance ticket.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.maintenance != null;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dialogWidth = math.min(620.0, MediaQuery.of(context).size.width * 0.95);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.build_circle_rounded, color: Color(0xFFF59E0B), size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isEdit ? 'Edit Maintenance Request (${widget.maintenance!.requestCode})' : 'Log Maintenance Request',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 24),

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

            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      TextFormField(
                        controller: _titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Issue / Request Title *',
                          hintText: 'e.g. AC cooling unit leaking water',
                          prefixIcon: Icon(Icons.report_problem_outlined, size: 18),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Title is required' : null,
                      ),
                      const SizedBox(height: 12),

                      // Description
                      TextFormField(
                        controller: _descCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Detailed Description',
                          hintText: 'Specific location, symptoms, affected equipment...',
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Type, Priority & Status
                      Row(
                        children: [
                          Expanded(
                            child: AppSearchableDropdownFormField<String>.fromMenuItems(
                              initialValue: _requestType,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Type'),
                              items: _requestTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (v) => setState(() => _requestType = v ?? _requestType),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: AppSearchableDropdownFormField<String>.fromMenuItems(
                              initialValue: _priority,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Priority'),
                              items: _priorities.map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (v) => setState(() => _priority = v ?? _priority),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: AppSearchableDropdownFormField<String>.fromMenuItems(
                              initialValue: _status,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Status'),
                              items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (v) => setState(() => _status = v ?? _status),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Location Picker (Room / Floor)
                      Row(
                        children: [
                          Expanded(
                            child: AppSearchableDropdownFormField<String?>.fromMenuItems(
                              initialValue: _selectedRoomId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Target Room (Optional)',
                                prefixIcon: Icon(Icons.meeting_room_outlined, size: 18),
                              ),
                              hint: const Text('Entire Building / Common Area'),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('Entire Building / Common Area')),
                                ...widget.rooms.map((r) => DropdownMenuItem(
                                      value: r.id,
                                      child: Text('${r.roomNumber} - ${r.name}', style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis),
                                    )),
                              ],
                              onChanged: (v) {
                                setState(() {
                                  _selectedRoomId = v;
                                  if (v != null) {
                                    final match = widget.rooms.firstWhere((r) => r.id == v, orElse: () => widget.rooms.first);
                                    _selectedFloorId = match.floorId;
                                  }
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppSearchableDropdownFormField<String?>.fromMenuItems(
                              initialValue: _selectedFloorId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Floor',
                                prefixIcon: Icon(Icons.layers_outlined, size: 18),
                              ),
                              hint: const Text('All Floors'),
                              items: [
                                const DropdownMenuItem(value: null, child: Text('All Floors')),
                                ...widget.floors.map((f) => DropdownMenuItem(
                                      value: f.id,
                                      child: Text(f.name, style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis),
                                    )),
                              ],
                              onChanged: (v) => setState(() => _selectedFloorId = v),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Assigned Technician / Staff (From User Management)
                      RawAutocomplete<Map<String, dynamic>>(
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) return _staffUsers;
                          final q = textEditingValue.text.toLowerCase();
                          return _staffUsers.where((u) {
                            final name = (u['full_name'] ?? '').toString().toLowerCase();
                            final role = (u['role'] ?? '').toString().toLowerCase();
                            return name.contains(q) || role.contains(q);
                          });
                        },
                        displayStringForOption: (u) => (u['full_name'] ?? '').toString(),
                        focusNode: _assignedFocusNode,
                        textEditingController: _assignedCtrl,
                        onSelected: (u) {
                          _assignedCtrl.text = (u['full_name'] ?? '').toString();
                        },
                        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              labelText: 'Assigned Technician / Staff Incharge',
                              hintText: 'Search user by name from User Management',
                              prefixIcon: const Icon(Icons.engineering_outlined, size: 18),
                              suffixIcon: _staffUsers.isNotEmpty ? const Icon(Icons.arrow_drop_down, size: 20) : null,
                            ),
                          );
                        },
                        optionsViewBuilder: (context, onSelected, options) {
                          return Align(
                            alignment: Alignment.topLeft,
                            child: Material(
                              elevation: 4,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: dialogWidth - 40,
                                constraints: const BoxConstraints(maxHeight: 200),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                ),
                                child: ListView.builder(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  itemCount: options.length,
                                  itemBuilder: (context, idx) {
                                    final u = options.elementAt(idx);
                                    return ListTile(
                                      dense: true,
                                      title: Text(u['full_name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                      subtitle: Text('${u['role'] ?? ''} • ${u['department'] ?? ''}', style: const TextStyle(fontSize: 11)),
                                      onTap: () => onSelected(u),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 14),

                      // Costs & Date
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _estCostCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Estimated Cost (₹/\$)', prefixIcon: Icon(Icons.price_change_outlined, size: 18)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _actCostCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Actual Cost (₹/\$)', prefixIcon: Icon(Icons.receipt_long_outlined, size: 18)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: _preferredDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2040),
                                );
                                if (d != null) setState(() => _preferredDate = d);
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(labelText: 'Scheduled Date', prefixIcon: Icon(Icons.calendar_today, size: 16)),
                                child: Text(
                                  _preferredDate != null
                                      ? '${_preferredDate!.day.toString().padLeft(2, '0')}/${_preferredDate!.month.toString().padLeft(2, '0')}/${_preferredDate!.year}'
                                      : 'Not set',
                                  style: TextStyle(fontSize: 12.5, color: _preferredDate == null ? Colors.grey : null),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Resolution Notes
                      TextFormField(
                        controller: _notesCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Resolution / Technician Work Notes',
                          hintText: 'Action taken, replaced spare parts, vendor invoice ref...',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 24),

            Wrap(
              alignment: WrapAlignment.end,
              spacing: 10,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  ),
                  child: _isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(isEdit ? 'Save Changes' : 'Log Request'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
