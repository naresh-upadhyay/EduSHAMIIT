import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/campus_models.dart';
import '../../services/campus_api_service.dart';
import '../../services/campus_lookup_helper.dart';

class AddEditBuildingOccupancyDialog extends StatefulWidget {
  final BuildingModel building;
  final List<RoomModel> rooms;
  final BuildingOccupancyModel? occupancy;
  final VoidCallback onSaved;

  const AddEditBuildingOccupancyDialog({
    super.key,
    required this.building,
    required this.rooms,
    this.occupancy,
    required this.onSaved,
  });

  @override
  State<AddEditBuildingOccupancyDialog> createState() => _AddEditBuildingOccupancyDialogState();
}

class _AddEditBuildingOccupancyDialogState extends State<AddEditBuildingOccupancyDialog> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedRoomId;
  String _referenceModule = 'Academics';
  late TextEditingController _targetNameCtrl;
  late TextEditingController _purposeCtrl;
  late TextEditingController _assignedToCtrl;
  late TextEditingController _notesCtrl;
  String _status = 'Active';
  DateTime? _startDate;
  DateTime? _endDate;

  bool _isSaving = false;
  String? _error;

  List<Map<String, dynamic>> _staffUsers = [];
  final _assignedFocusNode = FocusNode();
  final List<String> _modules = [
    'Academics', 'Timetable', 'Examinations', 'Staff Office', 'Hostel',
    'Library & Study', 'Laboratories', 'Administration', 'Sports', 'Other'
  ];

  @override
  void initState() {
    super.initState();
    final occ = widget.occupancy;
    _selectedRoomId = occ?.roomId ?? (widget.rooms.isNotEmpty ? widget.rooms.first.id : null);
    _targetNameCtrl = TextEditingController(text: occ?.referenceName ?? '');
    _purposeCtrl = TextEditingController(text: occ?.assignmentPurpose ?? 'Daily Class Instruction');
    _assignedToCtrl = TextEditingController(text: occ?.assignedToName ?? '');
    _notesCtrl = TextEditingController(text: occ?.notes ?? '');

    if (occ != null) {
      if (_modules.contains(occ.referenceModule)) _referenceModule = occ.referenceModule;
      _status = occ.status;
      if (occ.startDate != null) _startDate = DateTime.tryParse(occ.startDate!);
      if (occ.endDate != null) _endDate = DateTime.tryParse(occ.endDate!);
    } else {
      _startDate = DateTime.now();
      _endDate = DateTime.now().add(const Duration(days: 365));
    }

    _loadStaffUsers();
  }

  Future<void> _loadStaffUsers() async {
    final users = await CampusLookupHelper.instance.getStaffUsers();
    if (mounted) setState(() => _staffUsers = users);
  }

  @override
  void dispose() {
    _targetNameCtrl.dispose();
    _purposeCtrl.dispose();
    _assignedToCtrl.dispose();
    _notesCtrl.dispose();
    _assignedFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedRoomId == null || _selectedRoomId!.isEmpty) {
      setState(() => _error = 'Please select a room to allocate.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    final payload = {
      'room_id': _selectedRoomId,
      'reference_module': _referenceModule,
      'reference_name': _targetNameCtrl.text.trim(),
      'assignment_purpose': _purposeCtrl.text.trim(),
      'assigned_to_name': _assignedToCtrl.text.trim().isNotEmpty ? _assignedToCtrl.text.trim() : null,
      'start_date': _startDate != null ? '${_startDate!.year}-${_startDate!.month.toString().padLeft(2, '0')}-${_startDate!.day.toString().padLeft(2, '0')}' : null,
      'end_date': _endDate != null ? '${_endDate!.year}-${_endDate!.month.toString().padLeft(2, '0')}-${_endDate!.day.toString().padLeft(2, '0')}' : null,
      'status': _status,
      'notes': _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
    };

    final res = await CampusApiService.instance.saveBuildingOccupancy(
      widget.building.id,
      payload,
      assignmentId: widget.occupancy?.id,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (res['success'] == true) {
        Navigator.of(context).pop();
        widget.onSaved();
      } else {
        setState(() => _error = res['message'] ?? 'Failed to save space allocation.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.occupancy != null;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dialogWidth = math.min(600.0, MediaQuery.of(context).size.width * 0.95);

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
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.people_alt_rounded, color: Color(0xFF10B981), size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isEdit ? 'Edit Space Allocation' : 'Allocate Room / Space (${widget.building.name})',
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
                      // Target Room Picker
                      AppSearchableDropdownFormField<String>.fromMenuItems(
                        initialValue: _selectedRoomId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Select Room to Allocate *',
                          prefixIcon: Icon(Icons.meeting_room_outlined, size: 18),
                        ),
                        items: widget.rooms
                            .map((r) => DropdownMenuItem(
                                  value: r.id,
                                  child: Text('${r.roomNumber} - ${r.name} (${r.roomType}, Cap: ${r.maxCapacity})',
                                      style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedRoomId = v),
                        validator: (v) => v == null || v.isEmpty ? 'Room selection is required' : null,
                      ),
                      const SizedBox(height: 14),

                      // Allocation Module & Status
                      Row(
                        children: [
                          Expanded(
                            child: AppSearchableDropdownFormField<String>.fromMenuItems(
                              initialValue: _referenceModule,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Allocation Module',
                                prefixIcon: Icon(Icons.domain_verification_outlined, size: 18),
                              ),
                              items: _modules
                                  .map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis)))
                                  .toList(),
                              onChanged: (v) => setState(() => _referenceModule = v ?? _referenceModule),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AppSearchableDropdownFormField<String>.fromMenuItems(
                              initialValue: _status,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Allocation Status',
                                prefixIcon: Icon(Icons.check_circle_outline, size: 18),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'Active', child: Text('Active')),
                                DropdownMenuItem(value: 'Reserved', child: Text('Reserved')),
                                DropdownMenuItem(value: 'Released', child: Text('Released / Inactive')),
                              ],
                              onChanged: (v) => setState(() => _status = v ?? _status),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Target Entity / Section / Person
                      TextFormField(
                        controller: _targetNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Target Entity / Class / Section *',
                          hintText: 'e.g. Grade 11 - Science A, Staff Office, Examination Hall',
                          prefixIcon: Icon(Icons.groups_outlined, size: 18),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Target entity name is required' : null,
                      ),
                      const SizedBox(height: 14),

                      // Assignment Purpose
                      TextFormField(
                        controller: _purposeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Allocation Purpose',
                          hintText: 'e.g. Daily Class Instruction, Weekly Physics Lab, Faculty Desk',
                          prefixIcon: Icon(Icons.flag_outlined, size: 18),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Assigned Incharge (from User Management)
                      RawAutocomplete<Map<String, dynamic>>(
                        optionsBuilder: (TextEditingValue textEditingValue) {
                          if (textEditingValue.text.isEmpty) return _staffUsers;
                          final q = textEditingValue.text.toLowerCase();
                          return _staffUsers.where((u) {
                            final name = (u['full_name'] ?? '').toString().toLowerCase();
                            final email = (u['email'] ?? '').toString().toLowerCase();
                            final role = (u['role'] ?? '').toString().toLowerCase();
                            return name.contains(q) || email.contains(q) || role.contains(q);
                          });
                        },
                        displayStringForOption: (u) => (u['full_name'] ?? '').toString(),
                        focusNode: _assignedFocusNode,
                        textEditingController: _assignedToCtrl,
                        onSelected: (u) {
                          _assignedToCtrl.text = (u['full_name'] ?? '').toString();
                        },
                        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              labelText: 'Assigned Incharge / Teacher (User Management)',
                              hintText: 'Select or search user by name / role',
                              prefixIcon: const Icon(Icons.person_search_rounded, size: 18),
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

                      // Schedule Dates
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: _startDate ?? DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2040),
                                );
                                if (d != null) setState(() => _startDate = d);
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(labelText: 'Start Date', prefixIcon: Icon(Icons.calendar_today, size: 16)),
                                child: Text(
                                  _startDate != null
                                      ? '${_startDate!.day.toString().padLeft(2, '0')}/${_startDate!.month.toString().padLeft(2, '0')}/${_startDate!.year}'
                                      : 'Not set',
                                  style: TextStyle(fontSize: 12.5, color: _startDate == null ? Colors.grey : null),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: _endDate ?? DateTime.now().add(const Duration(days: 365)),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(2040),
                                );
                                if (d != null) setState(() => _endDate = d);
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(labelText: 'End Date', prefixIcon: Icon(Icons.event_repeat, size: 16)),
                                child: Text(
                                  _endDate != null
                                      ? '${_endDate!.day.toString().padLeft(2, '0')}/${_endDate!.month.toString().padLeft(2, '0')}/${_endDate!.year}'
                                      : 'No end date',
                                  style: TextStyle(fontSize: 12.5, color: _endDate == null ? Colors.grey : null),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Notes
                      TextFormField(
                        controller: _notesCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Allocation Notes / Schedule Details',
                          hintText: 'e.g. Monday to Friday 09:00 - 15:30, Key assigned to class monitor',
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
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  ),
                  child: _isSaving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(isEdit ? 'Save Changes' : 'Confirm Allocation'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
