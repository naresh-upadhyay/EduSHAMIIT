import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/campus_models.dart';
import '../../services/campus_api_service.dart';
import '../../services/campus_lookup_helper.dart';

class AddEditRoomDialog extends StatefulWidget {
  final BuildingModel building;
  final List<BuildingFloorModel> floors;
  final RoomModel? room;
  final VoidCallback? onSaved;
  final void Function(String floorId)? onSavedWithFloor;

  const AddEditRoomDialog({
    super.key,
    required this.building,
    required this.floors,
    this.room,
    this.onSaved,
    this.onSavedWithFloor,
  });

  @override
  State<AddEditRoomDialog> createState() => _AddEditRoomDialogState();
}

class _AddEditRoomDialogState extends State<AddEditRoomDialog> {
  final _formKey = GlobalKey<FormState>();

  late String _selectedFloorId;
  late TextEditingController _numberCtrl;
  late TextEditingController _nameCtrl;
  late TextEditingController _codeCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _areaCtrl;
  late TextEditingController _lengthCtrl;
  late TextEditingController _widthCtrl;
  late TextEditingController _maxCapCtrl;
  late TextEditingController _recCapCtrl;
  late TextEditingController _seatingCtrl;
  late TextEditingController _bedCtrl;
  late TextEditingController _workstationCtrl;
  late TextEditingController _doorsCtrl;
  late TextEditingController _windowsCtrl;
  late TextEditingController _deptCtrl;
  late TextEditingController _personCtrl;

  String _roomType = 'Classroom';
  String _operationalStatus = 'Available';
  String _assignmentStatus = 'Unassigned';
  bool _isAccessible = false;
  String _liftProximity = 'Nearby';
  String _exitProximity = 'Nearby';

  bool _isSaving = false;
  String? _error;

  List<String> _roomTypes = [];
  List<String> _operationalStatuses = [];
  List<String> _assignmentStatuses = [];
  List<String> _departments = [];
  List<Map<String, dynamic>> _staffUsers = [];
  final _deptFocusNode = FocusNode();
  final _personFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _roomTypes = CampusLookupHelper.instance.getImmediateLabels('ROOM_TYPE');
    _operationalStatuses = CampusLookupHelper.instance.getImmediateLabels('ROOM_STATUS');
    _assignmentStatuses = CampusLookupHelper.instance.getImmediateLabels('ROOM_ASSIGNMENT_STATUS');
    _loadAsyncLookups();
    final r = widget.room;
    _selectedFloorId = r?.floorId ?? (widget.floors.isNotEmpty ? widget.floors.first.id : '');

    _numberCtrl = TextEditingController(text: r?.roomNumber ?? '');
    _nameCtrl = TextEditingController(text: r?.name ?? '');
    _codeCtrl = TextEditingController(text: r?.roomCode ?? '');
    _descCtrl = TextEditingController(text: r?.description ?? '');
    _areaCtrl = TextEditingController(text: r != null ? '${r.area}' : '600');
    _lengthCtrl = TextEditingController(text: r != null ? '${r.length}' : '30');
    _widthCtrl = TextEditingController(text: r != null ? '${r.width}' : '20');
    _maxCapCtrl = TextEditingController(text: r != null ? '${r.maxCapacity}' : '40');
    _recCapCtrl = TextEditingController(text: r != null ? '${r.recommendedCapacity}' : '35');
    _seatingCtrl = TextEditingController(text: r != null ? '${r.seatingCapacity}' : '40');
    _bedCtrl = TextEditingController(text: r != null ? '${r.bedCount}' : '0');
    _workstationCtrl = TextEditingController(text: r != null ? '${r.workstationCount}' : '0');
    _doorsCtrl = TextEditingController(text: r != null ? '${r.numDoors}' : '1');
    _windowsCtrl = TextEditingController(text: r != null ? '${r.numWindows}' : '2');
    _deptCtrl = TextEditingController(text: r?.responsibleDepartment ?? '');
    _personCtrl = TextEditingController(text: r?.responsiblePersonName ?? '');

    if (r != null) {
      if (_roomTypes.contains(r.roomType)) _roomType = r.roomType;
      if (_operationalStatuses.contains(r.operationalStatus)) _operationalStatus = r.operationalStatus;
      if (_assignmentStatuses.contains(r.assignmentStatus)) _assignmentStatus = r.assignmentStatus;
      _isAccessible = r.isDifferentlyAbledAccessible;
      _liftProximity = r.liftProximity;
      _exitProximity = r.emergencyExitProximity;
    }
  }

  Future<void> _loadAsyncLookups() async {
    final rTypes = await CampusLookupHelper.instance.getLookupLabels('ROOM_TYPE');
    final opStats = await CampusLookupHelper.instance.getLookupLabels('ROOM_STATUS');
    final asStats = await CampusLookupHelper.instance.getLookupLabels('ROOM_ASSIGNMENT_STATUS');
    final staff = await CampusLookupHelper.instance.getStaffUsers();
    final depts = await CampusLookupHelper.instance.getDepartments();
    if (mounted) {
      setState(() {
        _roomTypes = rTypes;
        _operationalStatuses = opStats;
        _assignmentStatuses = asStats;
        _staffUsers = staff;
        _departments = depts;
        if (!_roomTypes.contains(_roomType) && _roomTypes.isNotEmpty) {
          _roomType = _roomTypes.first;
        }
        if (!_operationalStatuses.contains(_operationalStatus) && _operationalStatuses.isNotEmpty) {
          _operationalStatus = _operationalStatuses.first;
        }
        if (!_assignmentStatuses.contains(_assignmentStatus) && _assignmentStatuses.isNotEmpty) {
          _assignmentStatus = _assignmentStatuses.first;
        }
      });
    }
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    _descCtrl.dispose();
    _areaCtrl.dispose();
    _lengthCtrl.dispose();
    _widthCtrl.dispose();
    _maxCapCtrl.dispose();
    _recCapCtrl.dispose();
    _seatingCtrl.dispose();
    _bedCtrl.dispose();
    _workstationCtrl.dispose();
    _doorsCtrl.dispose();
    _windowsCtrl.dispose();
    _deptCtrl.dispose();
    _personCtrl.dispose();
    _deptFocusNode.dispose();
    _personFocusNode.dispose();
    super.dispose();
  }

  bool get _isHostel => _roomType.contains('Hostel') || _roomType.contains('Dormitory');
  bool get _isWashroom => _roomType.contains('Washroom') || _roomType.contains('Toilet') || _roomType.contains('Bathroom');
  bool get _isComputerLab => _roomType.contains('Computer') || _roomType.contains('Server');

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });

    final payload = {
      'building_id': widget.building.id,
      'floor_id': _selectedFloorId,
      'room_number': _numberCtrl.text.trim(),
      'name': _nameCtrl.text.trim().isNotEmpty ? _nameCtrl.text.trim() : 'Room ${_numberCtrl.text.trim()}',
      'room_code': _codeCtrl.text.trim().isNotEmpty ? _codeCtrl.text.trim() : 'RM-${_numberCtrl.text.trim()}',
      'room_type': _roomType,
      'description': _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
      'area': double.tryParse(_areaCtrl.text) ?? 0.0,
      'length': double.tryParse(_lengthCtrl.text) ?? 0.0,
      'width': double.tryParse(_widthCtrl.text) ?? 0.0,
      'max_capacity': int.tryParse(_maxCapCtrl.text) ?? 0,
      'recommended_capacity': int.tryParse(_recCapCtrl.text) ?? 0,
      'seating_capacity': _isWashroom ? 0 : (int.tryParse(_seatingCtrl.text) ?? 0),
      'bed_count': _isHostel ? (int.tryParse(_bedCtrl.text) ?? 0) : 0,
      'workstation_count': _isComputerLab ? (int.tryParse(_workstationCtrl.text) ?? 0) : 0,
      'num_doors': int.tryParse(_doorsCtrl.text) ?? 1,
      'num_windows': int.tryParse(_windowsCtrl.text) ?? 2,
      'operational_status': _operationalStatus,
      'assignment_status': _assignmentStatus,
      'is_differently_abled_accessible': _isAccessible,
      'lift_proximity': _liftProximity,
      'emergency_exit_proximity': _exitProximity,
      'responsible_department': _deptCtrl.text.trim().isNotEmpty ? _deptCtrl.text.trim() : null,
      'responsible_person_name': _personCtrl.text.trim().isNotEmpty ? _personCtrl.text.trim() : null,
    };

    final res = await CampusApiService.instance.saveRoom(
      payload,
      roomId: widget.room?.id,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (res['success'] == true) {
        Navigator.of(context).pop();
        widget.onSavedWithFloor?.call(_selectedFloorId);
        widget.onSaved?.call();
      } else {
        setState(() => _error = res['message'] ?? 'Failed to save room.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.room != null;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final dialogWidth = math.min(680.0, screenWidth * 0.95);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(isEdit ? Icons.edit_note_rounded : Icons.meeting_room_rounded, color: const Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isEdit ? 'Edit Room (${widget.room!.roomNumber})' : 'Add New Room / Space',
                          style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),

            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 540;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Section 1: Basic Information
                          const Text('1. Space & Identity', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF2563EB))),
                          const SizedBox(height: 10),

                          if (isCompact) ...[
                            AppSearchableDropdownFormField<String>.fromMenuItems(
                              initialValue: _selectedFloorId.isNotEmpty ? _selectedFloorId : null,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Floor *'),
                              items: widget.floors.map((f) => DropdownMenuItem(value: f.id, child: Text(f.name, style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (v) => setState(() => _selectedFloorId = v ?? _selectedFloorId),
                              validator: (v) => v == null || v.isEmpty ? 'Floor required' : null,
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _numberCtrl,
                              decoration: const InputDecoration(labelText: 'Room Number *', hintText: 'e.g. 101'),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _codeCtrl,
                              decoration: const InputDecoration(labelText: 'Room Code', hintText: 'e.g. RM-101'),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _nameCtrl,
                              decoration: const InputDecoration(labelText: 'Room Display Name *', hintText: 'e.g. Physics Laboratory Alpha'),
                              validator: (v) => v == null || v.trim().isEmpty ? 'Name required' : null,
                            ),
                            const SizedBox(height: 10),
                            AppSearchableDropdownFormField<String>.fromMenuItems(
                              initialValue: _roomType,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Room Type'),
                              items: _roomTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (v) => setState(() => _roomType = v ?? _roomType),
                            ),
                            const SizedBox(height: 10),
                            AppSearchableDropdownFormField<String>.fromMenuItems(
                              initialValue: _operationalStatus,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Operational Status'),
                              items: _operationalStatuses.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (v) => setState(() => _operationalStatus = v ?? _operationalStatus),
                            ),
                            const SizedBox(height: 10),
                            AppSearchableDropdownFormField<String>.fromMenuItems(
                              initialValue: _assignmentStatus,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Assignment Status'),
                              items: _assignmentStatuses.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
                              onChanged: (v) => setState(() => _assignmentStatus = v ?? _assignmentStatus),
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: AppSearchableDropdownFormField<String>.fromMenuItems(
                                    initialValue: _selectedFloorId.isNotEmpty ? _selectedFloorId : null,
                                    isExpanded: true,
                                    decoration: const InputDecoration(labelText: 'Floor *'),
                                    items: widget.floors.map((f) => DropdownMenuItem(value: f.id, child: Text(f.name, style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis))).toList(),
                                    onChanged: (v) => setState(() => _selectedFloorId = v ?? _selectedFloorId),
                                    validator: (v) => v == null || v.isEmpty ? 'Floor required' : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _numberCtrl,
                                    decoration: const InputDecoration(labelText: 'Room Number *', hintText: 'e.g. 101, G001, B1-01'),
                                    validator: (v) => v == null || v.trim().isEmpty ? 'Room number required' : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _codeCtrl,
                                    decoration: const InputDecoration(labelText: 'Room Code', hintText: 'e.g. RM-101'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: TextFormField(
                                    controller: _nameCtrl,
                                    decoration: const InputDecoration(labelText: 'Room Display Name *', hintText: 'e.g. Physics Laboratory Alpha'),
                                    validator: (v) => v == null || v.trim().isEmpty ? 'Name required' : null,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  flex: 4,
                                  child: AppSearchableDropdownFormField<String>.fromMenuItems(
                                    initialValue: _roomType,
                                    isExpanded: true,
                                    decoration: const InputDecoration(labelText: 'Room Type'),
                                    items: _roomTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
                                    onChanged: (v) => setState(() => _roomType = v ?? _roomType),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: AppSearchableDropdownFormField<String>.fromMenuItems(
                                    initialValue: _operationalStatus,
                                    isExpanded: true,
                                    decoration: const InputDecoration(labelText: 'Operational Status'),
                                    items: _operationalStatuses.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
                                    onChanged: (v) => setState(() => _operationalStatus = v ?? _operationalStatus),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: AppSearchableDropdownFormField<String>.fromMenuItems(
                                    initialValue: _assignmentStatus,
                                    isExpanded: true,
                                    decoration: const InputDecoration(labelText: 'Assignment Status'),
                                    items: _assignmentStatuses.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
                                    onChanged: (v) => setState(() => _assignmentStatus = v ?? _assignmentStatus),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 18),

                          // Section 2: Physical Specifications
                          const Text('2. Dimensions & Capacity', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF2563EB))),
                          const SizedBox(height: 10),

                          if (isCompact) ...[
                            TextFormField(
                              controller: _areaCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Area (sq ft)', hintText: '600'),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _lengthCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Length (ft)', hintText: '30'),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _widthCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(labelText: 'Width (ft)', hintText: '20'),
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _maxCapCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Max Capacity *', hintText: '40'),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Required';
                                final n = int.tryParse(v);
                                if (n == null || n < 0) return 'Cannot be negative';
                                return null;
                              },
                            ),
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _recCapCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(labelText: 'Rec. Capacity', hintText: '35'),
                            ),
                            if (!_isWashroom) ...[
                              const SizedBox(height: 10),
                              TextFormField(
                                controller: _seatingCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Seating Places', hintText: '40'),
                              ),
                            ],
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _areaCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(labelText: 'Area (sq ft)', hintText: '600'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _lengthCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(labelText: 'Length (ft)', hintText: '30'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _widthCtrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: const InputDecoration(labelText: 'Width (ft)', hintText: '20'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _maxCapCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Max Capacity *', hintText: '40'),
                                    validator: (v) {
                                      if (v == null || v.trim().isEmpty) return 'Required';
                                      final n = int.tryParse(v);
                                      if (n == null || n < 0) return 'Cannot be negative';
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: TextFormField(
                                    controller: _recCapCtrl,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(labelText: 'Recommended Capacity', hintText: '35'),
                                  ),
                                ),
                                if (!_isWashroom) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _seatingCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(labelText: 'Seating Places', hintText: '40'),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],

                          // Conditional row for Beds or Workstations
                          if (_isHostel || _isComputerLab) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                if (_isHostel)
                                  Expanded(
                                    child: TextFormField(
                                      controller: _bedCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(labelText: 'Bed Count *', hintText: '4'),
                                    ),
                                  ),
                                if (_isHostel && _isComputerLab) const SizedBox(width: 12),
                                if (_isComputerLab)
                                  Expanded(
                                    child: TextFormField(
                                      controller: _workstationCtrl,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(labelText: 'Computer Workstations *', hintText: '30'),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 18),

                          // Section 3: Accessibility & Location Notes
                          const Text('3. Accessibility & Safety', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF2563EB))),
                          const SizedBox(height: 10),
                          if (isCompact) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Flexible(
                                  child: Text('Differently Abled Accessible', style: TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis),
                                ),
                                Switch(
                                  value: _isAccessible,
                                  onChanged: (v) => setState(() => _isAccessible = v),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            AppSearchableDropdownFormField<String>.fromMenuItems(
                              initialValue: _liftProximity,
                              isExpanded: true,
                              decoration: const InputDecoration(labelText: 'Lift Proximity'),
                              items: const [
                                DropdownMenuItem(value: 'Direct Access', child: Text('Direct Access', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'Nearby', child: Text('Nearby (< 20m)', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'Far', child: Text('Far (> 50m)', overflow: TextOverflow.ellipsis)),
                                DropdownMenuItem(value: 'None', child: Text('None / Staircase Only', overflow: TextOverflow.ellipsis)),
                              ],
                              onChanged: (v) => setState(() => _liftProximity = v ?? _liftProximity),
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: SwitchListTile(
                                    title: const Text('Differently Abled Accessible', style: TextStyle(fontSize: 12.5)),
                                    value: _isAccessible,
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    onChanged: (v) => setState(() => _isAccessible = v),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: AppSearchableDropdownFormField<String>.fromMenuItems(
                                    initialValue: _liftProximity,
                                    isExpanded: true,
                                    decoration: const InputDecoration(labelText: 'Lift Proximity'),
                                    items: const [
                                      DropdownMenuItem(value: 'Direct Access', child: Text('Direct Access', overflow: TextOverflow.ellipsis)),
                                      DropdownMenuItem(value: 'Nearby', child: Text('Nearby (< 20m)', overflow: TextOverflow.ellipsis)),
                                      DropdownMenuItem(value: 'Far', child: Text('Far (> 50m)', overflow: TextOverflow.ellipsis)),
                                      DropdownMenuItem(value: 'None', child: Text('None / Staircase Only', overflow: TextOverflow.ellipsis)),
                                    ],
                                    onChanged: (v) => setState(() => _liftProximity = v ?? _liftProximity),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 18),

                          // Section 4: Management & Incharge
                          const Text('4. Assignment & Department', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF2563EB))),
                          const SizedBox(height: 10),
                          if (isCompact) ...[
                            RawAutocomplete<String>(
                              optionsBuilder: (TextEditingValue textEditingValue) {
                                if (textEditingValue.text.isEmpty) return _departments;
                                final q = textEditingValue.text.toLowerCase();
                                return _departments.where((d) => d.toLowerCase().contains(q));
                              },
                              focusNode: _deptFocusNode,
                              textEditingController: _deptCtrl,
                              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                return TextFormField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  decoration: InputDecoration(
                                    labelText: 'Responsible Department',
                                    hintText: 'Select or type department',
                                    prefixIcon: const Icon(Icons.business_outlined, size: 18),
                                    suffixIcon: _departments.isNotEmpty ? const Icon(Icons.arrow_drop_down, size: 20) : null,
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
                                      constraints: const BoxConstraints(maxHeight: 180),
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
                                          final d = options.elementAt(idx);
                                          return ListTile(
                                            dense: true,
                                            title: Text(d, style: const TextStyle(fontSize: 12.5)),
                                            onTap: () => onSelected(d),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 10),
                            RawAutocomplete<Map<String, dynamic>>(
                              optionsBuilder: (TextEditingValue textEditingValue) {
                                if (textEditingValue.text.isEmpty) return _staffUsers;
                                final q = textEditingValue.text.toLowerCase();
                                return _staffUsers.where((u) {
                                  final name = (u['full_name'] ?? u['username'] ?? '').toString().toLowerCase();
                                  final role = (u['role'] ?? '').toString().toLowerCase();
                                  final dept = (u['department'] ?? '').toString().toLowerCase();
                                  return name.contains(q) || role.contains(q) || dept.contains(q);
                                });
                              },
                              displayStringForOption: (u) => (u['full_name'] ?? u['username'] ?? '').toString(),
                              focusNode: _personFocusNode,
                              textEditingController: _personCtrl,
                              onSelected: (u) {
                                final name = (u['full_name'] ?? u['username'] ?? '').toString();
                                _personCtrl.text = name;
                                final dept = (u['department'] ?? '').toString();
                                if (dept.isNotEmpty && _deptCtrl.text.trim().isEmpty) {
                                  _deptCtrl.text = dept;
                                }
                              },
                              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                return TextFormField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  decoration: InputDecoration(
                                    labelText: 'Incharge Person Name',
                                    hintText: 'Search user from User Management',
                                    prefixIcon: const Icon(Icons.person_outline, size: 18),
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
                                          final name = (u['full_name'] ?? u['username'] ?? '').toString();
                                          final role = (u['role'] ?? '').toString();
                                          final dept = (u['department'] ?? '').toString();
                                          return ListTile(
                                            dense: true,
                                            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                            subtitle: Text(
                                              [if (role.isNotEmpty) role, if (dept.isNotEmpty) dept].join(' • '),
                                              style: const TextStyle(fontSize: 11),
                                            ),
                                            onTap: () => onSelected(u),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: RawAutocomplete<String>(
                                    optionsBuilder: (TextEditingValue textEditingValue) {
                                      if (textEditingValue.text.isEmpty) return _departments;
                                      final q = textEditingValue.text.toLowerCase();
                                      return _departments.where((d) => d.toLowerCase().contains(q));
                                    },
                                    focusNode: _deptFocusNode,
                              textEditingController: _deptCtrl,
                                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                      return TextFormField(
                                        controller: controller,
                                        focusNode: focusNode,
                                        decoration: InputDecoration(
                                          labelText: 'Responsible Department',
                                          hintText: 'Select or type department',
                                          prefixIcon: const Icon(Icons.business_outlined, size: 18),
                                          suffixIcon: _departments.isNotEmpty ? const Icon(Icons.arrow_drop_down, size: 20) : null,
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
                                            width: (dialogWidth - 52) / 2,
                                            constraints: const BoxConstraints(maxHeight: 180),
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
                                                final d = options.elementAt(idx);
                                                return ListTile(
                                                  dense: true,
                                                  title: Text(d, style: const TextStyle(fontSize: 12.5)),
                                                  onTap: () => onSelected(d),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: RawAutocomplete<Map<String, dynamic>>(
                                    optionsBuilder: (TextEditingValue textEditingValue) {
                                      if (textEditingValue.text.isEmpty) return _staffUsers;
                                      final q = textEditingValue.text.toLowerCase();
                                      return _staffUsers.where((u) {
                                        final name = (u['full_name'] ?? u['username'] ?? '').toString().toLowerCase();
                                        final role = (u['role'] ?? '').toString().toLowerCase();
                                        final dept = (u['department'] ?? '').toString().toLowerCase();
                                        return name.contains(q) || role.contains(q) || dept.contains(q);
                                      });
                                    },
                                    displayStringForOption: (u) => (u['full_name'] ?? u['username'] ?? '').toString(),
                                    focusNode: _personFocusNode,
                              textEditingController: _personCtrl,
                                    onSelected: (u) {
                                      final name = (u['full_name'] ?? u['username'] ?? '').toString();
                                      _personCtrl.text = name;
                                      final dept = (u['department'] ?? '').toString();
                                      if (dept.isNotEmpty && _deptCtrl.text.trim().isEmpty) {
                                        _deptCtrl.text = dept;
                                      }
                                    },
                                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                                      return TextFormField(
                                        controller: controller,
                                        focusNode: focusNode,
                                        decoration: InputDecoration(
                                          labelText: 'Incharge Person Name',
                                          hintText: 'Search user from User Management',
                                          prefixIcon: const Icon(Icons.person_outline, size: 18),
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
                                            width: (dialogWidth - 52) / 2,
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
                                                final name = (u['full_name'] ?? u['username'] ?? '').toString();
                                                final role = (u['role'] ?? '').toString();
                                                final dept = (u['department'] ?? '').toString();
                                                return ListTile(
                                                  dense: true,
                                                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                                  subtitle: Text(
                                                    [if (role.isNotEmpty) role, if (dept.isNotEmpty) dept].join(' • '),
                                                    style: const TextStyle(fontSize: 11),
                                                  ),
                                                  onTap: () => onSelected(u),
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            const Divider(height: 20),

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
                      : Text(isEdit ? 'Save Changes' : 'Create Room'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
