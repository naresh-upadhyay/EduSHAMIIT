import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/hostel_models.dart';
import '../../providers/hostel_provider.dart';

class TransferStudentDialog extends ConsumerStatefulWidget {
  final HostelStudentOccupant? occupant;
  final HostelStudentOccupant? student;
  final String? currentRoomNumber;
  final String? currentRoomId;

  const TransferStudentDialog({
    super.key,
    this.occupant,
    this.student,
    this.currentRoomNumber,
    this.currentRoomId,
  });

  HostelStudentOccupant get actualStudent => (occupant ?? student)!;
  String get actualRoomNumber => currentRoomNumber ?? currentRoomId ?? '';

  @override
  ConsumerState<TransferStudentDialog> createState() => _TransferStudentDialogState();
}

class _TransferStudentDialogState extends ConsumerState<TransferStudentDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedBuildingId;
  String? _selectedFloorId;
  String? _selectedRoomId;
  String? _selectedBedId;

  List<HostelRoomItem> _targetRooms = [];
  HostelRoomDetail? _targetRoomDetail;
  bool _isLoadingRooms = false;
  bool _isLoadingDetail = false;
  bool _isTransferring = false;
  final TextEditingController _reasonController = TextEditingController(text: 'Room change request');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(hostelProvider);
      if (state.structureTree.isNotEmpty) {
        setState(() {
          _selectedBuildingId = state.structureTree.first.id;
        });
        _loadRooms();
      }
    });
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadRooms() async {
    if (_selectedBuildingId == null) return;
    setState(() => _isLoadingRooms = true);
    final notifier = ref.read(hostelProvider.notifier);
    final res = await notifier.service.getRooms(
      buildingId: _selectedBuildingId,
      floorId: _selectedFloorId,
      pageSize: 50,
    );
    if (mounted) {
      final rooms = (res['rooms'] as List<HostelRoomItem>?) ?? [];
      setState(() {
        _targetRooms = rooms.where((r) {
          final hasVacant = r.availableBeds > 0;
          final isNotCurrent = (widget.currentRoomId != null && r.id != widget.currentRoomId) &&
              r.roomNumber.trim().toLowerCase() != widget.actualRoomNumber.trim().toLowerCase();
          return hasVacant && isNotCurrent;
        }).toList();
        _isLoadingRooms = false;
        _selectedRoomId = null;
        _selectedBedId = null;
        _targetRoomDetail = null;
      });
    }
  }

  Future<void> _loadRoomDetail(String roomId) async {
    setState(() => _isLoadingDetail = true);
    final notifier = ref.read(hostelProvider.notifier);
    final detail = await notifier.service.getRoomDetail(roomId);
    if (mounted) {
      setState(() {
        _targetRoomDetail = detail;
        _isLoadingDetail = false;
        final avail = detail?.beds.where((b) => b.isAvailable || b.status.toUpperCase() == 'AVAILABLE').toList();
        _selectedBedId = (avail != null && avail.isNotEmpty) ? avail.first.id : null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hostelProvider);
    final notifier = ref.read(hostelProvider.notifier);
    final buildings = state.structureTree;

    final curBuilding = buildings.firstWhere(
      (b) => b.id == _selectedBuildingId,
      orElse: () => buildings.isNotEmpty ? buildings.first : state.structureTree.first,
    );
    final floors = curBuilding.floors;

    final availBeds = _targetRoomDetail?.beds
        .where((b) => b.isAvailable || b.status.toUpperCase() == 'AVAILABLE')
        .toList() ?? [];
    final safeBedId = availBeds.any((b) => b.id == _selectedBedId)
        ? _selectedBedId
        : (availBeds.isNotEmpty ? availBeds.first.id : null);

    final safeBuildingId = buildings.any((b) => b.id == _selectedBuildingId)
        ? _selectedBuildingId
        : (buildings.isNotEmpty ? buildings.first.id : null);

    final safeFloorId = floors.any((f) => f.id == _selectedFloorId) ? _selectedFloorId : null;

    final safeRoomId = _targetRooms.any((r) => r.id == _selectedRoomId) ? _selectedRoomId : null;

    return AlertDialog(
      title: Text('Transfer Student: ${widget.actualStudent.studentName}'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.swap_horiz, color: Colors.amber, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current: Room ${widget.actualRoomNumber} • ${widget.actualStudent.bedCode}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                            Text(
                              'Adm: ${widget.actualStudent.admissionNumber} | Checked In: ${widget.actualStudent.checkInDate}',
                              style: TextStyle(color: Colors.grey.shade700, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Transfer Target Location', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: safeBuildingId,
                        decoration: const InputDecoration(labelText: 'Target Building *'),
                        items: buildings.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (v) {
                          setState(() {
                            _selectedBuildingId = v;
                            _selectedFloorId = null;
                          });
                            _loadRooms();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: safeFloorId,
                        decoration: const InputDecoration(labelText: 'Target Floor'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All Floors')),
                          ...floors.map((f) => DropdownMenuItem(value: f.id, child: Text(f.name, overflow: TextOverflow.ellipsis))),
                        ],
                        onChanged: (v) {
                          setState(() => _selectedFloorId = v);
                          _loadRooms();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_isLoadingRooms)
                  const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
                else
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: safeRoomId,
                    decoration: const InputDecoration(labelText: 'Target Room (with available beds) *'),
                    items: _targetRooms.map((r) {
                      return DropdownMenuItem(
                        value: r.id,
                        child: Text('${r.roomNumber} (${r.roomType}) - ${r.availableBeds} beds available', overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: (v) {
                      setState(() => _selectedRoomId = v);
                      if (v != null) _loadRoomDetail(v);
                    },
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                const SizedBox(height: 12),
                if (_isLoadingDetail)
                  const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()))
                else if (_targetRoomDetail != null) ...[
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: safeBedId,
                    decoration: const InputDecoration(labelText: 'Target Bed *'),
                    items: availBeds
                        .map((b) => DropdownMenuItem(value: b.id, child: Text('${b.bedNumber} (${b.bedType}) - ₹${b.monthlyPrice?.toInt() ?? 6000}/mo', overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (v) => setState(() => _selectedBedId = v),
                    validator: (v) => (v == null || v.isEmpty) ? 'Select an available bed' : null,
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _reasonController,
                  decoration: const InputDecoration(labelText: 'Reason for Transfer *'),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isTransferring ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isTransferring || _selectedBedId == null ? null : () async {
            if (!_formKey.currentState!.validate()) return;
            setState(() => _isTransferring = true);

            final payload = {
              'allocation_id': widget.actualStudent.allocationId,
              'new_building_id': _selectedBuildingId,
              'new_floor_id': _targetRoomDetail?.floorId ?? _selectedFloorId,
              'new_room_id': _selectedRoomId,
              'new_bed_id': _selectedBedId,
              'reason': _reasonController.text.trim(),
            };

            final navigator = Navigator.of(context);
            final res = await notifier.service.transferStudent(payload);
            if (mounted) {
              setState(() => _isTransferring = false);
              if (res['success'] == true) {
                navigator.pop();
                notifier.showSuccess('Student transferred successfully');
                final curSelectedRoomId = ref.read(hostelProvider).selectedRoomId;
                if (curSelectedRoomId != null) {
                  notifier.fetchRoomDetail(curSelectedRoomId);
                }
                notifier.fetchRooms();
                notifier.refreshAll();
              } else {
                final err = res['error'] ?? res['message'] ?? 'Transfer failed';
                notifier.showError(err.toString());
              }
            }
          },
          child: _isTransferring
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Confirm Transfer'),
        ),
      ],
    );
  }
}
