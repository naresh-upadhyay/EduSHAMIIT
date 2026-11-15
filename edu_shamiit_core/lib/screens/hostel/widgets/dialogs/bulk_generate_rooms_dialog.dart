import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/hostel_provider.dart';
import '../../services/hostel_lookup_helper.dart';

class BulkGenerateRoomsDialog extends ConsumerStatefulWidget {
  final String? defaultBuildingId;
  final String? defaultFloorId;
  final String? buildingId;
  final String? floorId;

  const BulkGenerateRoomsDialog({
    super.key,
    this.defaultBuildingId,
    this.defaultFloorId,
    this.buildingId,
    this.floorId,
  });

  @override
  ConsumerState<BulkGenerateRoomsDialog> createState() => _BulkGenerateRoomsDialogState();
}

class _BulkGenerateRoomsDialogState extends ConsumerState<BulkGenerateRoomsDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedBuildingId;
  String? _selectedFloorId;

  final TextEditingController _prefixController = TextEditingController(text: 'A-');
  final TextEditingController _startController = TextEditingController(text: '101');
  final TextEditingController _endController = TextEditingController(text: '110');
  final TextEditingController _capacityController = TextEditingController(text: '3');
  final TextEditingController _feeController = TextEditingController(text: '6000');
  final TextEditingController _sizeController = TextEditingController(text: '18.0');

  String _roomType = 'Standard';
  bool _autoCreateBeds = true;
  bool _isGenerating = false;
  bool _isLoadingLookups = true;

  List<String> _roomTypes = [];

  @override
  void initState() {
    super.initState();
    _selectedBuildingId = widget.buildingId ?? widget.defaultBuildingId;
    _selectedFloorId = widget.floorId ?? widget.defaultFloorId;
    _loadLookups();
  }

  Future<void> _loadLookups() async {
    try {
      final types = await HostelLookupHelper.instance.getActiveLookup('ROOM_TYPE');
      if (mounted) {
        setState(() {
          _roomTypes = types.map((e) => e.label).toList();
          if (_roomTypes.isNotEmpty && !_roomTypes.contains(_roomType)) {
            _roomTypes.insert(0, _roomType);
          }
          _isLoadingLookups = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _roomTypes = ['Standard', 'Deluxe', 'Super Deluxe', 'Dormitory', 'Single Occupancy'];
          _isLoadingLookups = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _prefixController.dispose();
    _startController.dispose();
    _endController.dispose();
    _capacityController.dispose();
    _feeController.dispose();
    _sizeController.dispose();
    super.dispose();
  }

  List<String> _getPreviewRooms() {
    final prefix = _prefixController.text.trim();
    final start = int.tryParse(_startController.text) ?? 1;
    final end = int.tryParse(_endController.text) ?? 1;
    if (end < start || end - start > 100) return [];
    return List.generate(end - start + 1, (i) => '$prefix${start + i}');
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hostelProvider);
    final notifier = ref.read(hostelProvider.notifier);

    final buildings = state.structureTree;
    if (_selectedBuildingId == null && buildings.isNotEmpty) {
      _selectedBuildingId = buildings.first.id;
    }

    final currentBuilding = buildings.firstWhere(
      (b) => b.id == _selectedBuildingId,
      orElse: () => buildings.isNotEmpty ? buildings.first : state.structureTree.first,
    );

    final floors = currentBuilding.floors;
    if ((_selectedFloorId == null || !floors.any((f) => f.id == _selectedFloorId)) && floors.isNotEmpty) {
      _selectedFloorId = floors.first.id;
    }

    final previews = _getPreviewRooms();
    final types = _roomTypes.isNotEmpty
        ? _roomTypes
        : ['Standard', 'Deluxe', 'Super Deluxe', 'Dormitory', 'Single Occupancy'];

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Bulk Generate Rooms'),
          if (_isLoadingLookups)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: buildings.any((b) => b.id == _selectedBuildingId) ? _selectedBuildingId : (buildings.isNotEmpty ? buildings.first.id : null),
                        decoration: const InputDecoration(labelText: 'Building *'),
                        items: buildings.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (v) {
                          setState(() {
                            _selectedBuildingId = v;
                            _selectedFloorId = null;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: floors.any((f) => f.id == _selectedFloorId) ? _selectedFloorId : (floors.isNotEmpty ? floors.first.id : null),
                        decoration: const InputDecoration(labelText: 'Floor *'),
                        items: floors.map((f) => DropdownMenuItem(value: f.id, child: Text(f.name, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (v) => setState(() => _selectedFloorId = v),
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _prefixController,
                        decoration: const InputDecoration(labelText: 'Prefix', hintText: 'A-'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _startController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Start *', hintText: '101'),
                        onChanged: (_) => setState(() {}),
                        validator: (v) => (v == null || int.tryParse(v) == null) ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _endController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'End *', hintText: '110'),
                        onChanged: (_) => setState(() {}),
                        validator: (v) => (v == null || int.tryParse(v) == null) ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: types.contains(_roomType) ? _roomType : types.first,
                        decoration: const InputDecoration(
                          labelText: 'Room Type',
                          helperText: 'From Lookup Management',
                        ),
                        items: types.map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (v) => setState(() => _roomType = v ?? 'Standard'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _capacityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Beds per Room *',
                          helperText: ' ',
                        ),
                        validator: (v) => (v == null || int.tryParse(v) == null) ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _feeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Monthly Fee (₹)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _sizeController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Size (sq.m)'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Auto-generate numbered beds for each room', style: TextStyle(fontSize: 13)),
                  subtitle: const Text('E.g. Bed 1, Bed 2, Bed 3', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  value: _autoCreateBeds,
                  onChanged: (v) => setState(() => _autoCreateBeds = v ?? true),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const Divider(height: 24),
                Text(
                  'Preview (${previews.length} rooms to create):',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: previews.isEmpty
                      ? const Center(child: Text('Invalid range', style: TextStyle(color: Colors.red)))
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: previews.map((r) {
                              return Container(
                                margin: const EdgeInsets.only(right: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: Colors.blue.shade200),
                                ),
                                child: Text(r, style: TextStyle(color: Colors.blue.shade800, fontSize: 12, fontWeight: FontWeight.w500)),
                              );
                            }).toList(),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isGenerating ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isGenerating || previews.isEmpty ? null : () async {
            if (!_formKey.currentState!.validate()) return;
            setState(() => _isGenerating = true);

            final data = {
              'building_id': _selectedBuildingId,
              'floor_id': _selectedFloorId,
              'prefix': _prefixController.text.trim(),
              'start_number': int.tryParse(_startController.text) ?? 1,
              'end_number': int.tryParse(_endController.text) ?? 1,
              'room_type': _roomType,
              'capacity': int.tryParse(_capacityController.text) ?? 3,
              'room_size_sqm': double.tryParse(_sizeController.text) ?? 18.0,
              'monthly_fee': double.tryParse(_feeController.text) ?? 6000.0,
              'auto_create_beds': _autoCreateBeds,
            };

            final navigator = Navigator.of(context);
            try {
              final res = await notifier.service.bulkGenerateRooms(data);
              if (mounted) {
                if (res['success'] == true) {
                  navigator.pop();
                  notifier.showSuccess('Generated ${previews.length} rooms successfully');
                  notifier.refreshAll();
                } else {
                  notifier.showError(res['message']?.toString() ?? 'Failed to bulk generate rooms');
                }
              }
            } catch (e) {
              if (mounted) {
                final msg = e.toString().replaceAll(RegExp(r'^(ApiException:|Exception:|\s*Api)+', caseSensitive: false), '').trim();
                notifier.showError(msg.isNotEmpty ? msg : 'Error generating rooms');
              }
            } finally {
              if (mounted) {
                setState(() => _isGenerating = false);
              }
            }
          },
          child: _isGenerating
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Generate Rooms'),
        ),
      ],
    );
  }
}
