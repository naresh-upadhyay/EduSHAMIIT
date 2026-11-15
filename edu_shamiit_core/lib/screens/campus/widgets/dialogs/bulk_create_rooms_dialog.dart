import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/campus_models.dart';
import '../../services/campus_api_service.dart';
import '../../services/campus_lookup_helper.dart';

class BulkCreateRoomsDialog extends StatefulWidget {
  final BuildingModel building;
  final List<BuildingFloorModel> floors;
  final VoidCallback onSaved;

  const BulkCreateRoomsDialog({
    super.key,
    required this.building,
    required this.floors,
    required this.onSaved,
  });

  @override
  State<BulkCreateRoomsDialog> createState() => _BulkCreateRoomsDialogState();
}

class _BulkCreateRoomsDialogState extends State<BulkCreateRoomsDialog> {
  late String _selectedFloorId;
  String _roomType = 'Classroom';
  final _roomNumbersCtrl = TextEditingController(text: '101, 102, 103, 104, 105');
  final _capacityCtrl = TextEditingController(text: '40');
  final Set<String> _selectedFacilities = {'Air Conditioning', 'Whiteboard', 'LED Projector'};

  bool _isSaving = false;
  String? _error;
  String? _successMsg;

  List<String> _roomTypes = [];
  final List<String> _facilitiesList = const [
    'Air Conditioning',
    'Whiteboard',
    'LED Projector',
    'Audio Sound System',
    'WiFi Access Point',
    'CCTV Security',
    'Smart Interactive Panel',
  ];

  @override
  void initState() {
    super.initState();
    _selectedFloorId = widget.floors.isNotEmpty ? widget.floors.first.id : '';
    _roomTypes = CampusLookupHelper.instance.getImmediateLabels('ROOM_TYPE');
    _loadLookups();
  }

  Future<void> _loadLookups() async {
    final types = await CampusLookupHelper.instance.getLookupLabels('ROOM_TYPE');
    if (mounted) {
      setState(() {
        _roomTypes = types;
        if (!_roomTypes.contains(_roomType) && _roomTypes.isNotEmpty) {
          _roomType = _roomTypes.first;
        }
      });
    }
  }

  @override
  void dispose() {
    _roomNumbersCtrl.dispose();
    _capacityCtrl.dispose();
    super.dispose();
  }

  List<String> get _parsedNumbers {
    return _roomNumbersCtrl.text
        .split(RegExp(r'[,;\n]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Future<void> _submit() async {
    final numbers = _parsedNumbers;
    if (numbers.isEmpty) {
      setState(() => _error = 'Please enter at least one room number.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    final payload = {
      'building_id': widget.building.id,
      'floor_id': _selectedFloorId,
      'room_type': _roomType,
      'room_numbers': numbers,
      'default_capacity': int.tryParse(_capacityCtrl.text) ?? 40,
      'facilities': _selectedFacilities.toList(),
    };

    final res = await CampusApiService.instance.bulkCreateRooms(payload);

    if (mounted) {
      setState(() => _isSaving = false);
      if (res['success'] == true) {
        setState(() => _successMsg = 'Successfully created ${res['count'] ?? numbers.length} rooms!');
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) {
          Navigator.of(context).pop();
          widget.onSaved();
        }
      } else {
        setState(() => _error = res['message'] ?? 'Failed to bulk create rooms.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nums = _parsedNumbers;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final dialogWidth = math.min(580.0, screenWidth * 0.95);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(maxHeight: screenHeight * 0.9),
        padding: const EdgeInsets.all(22),
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
                      const Icon(Icons.playlist_add_rounded, color: Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Bulk Create Rooms in ${widget.building.code}',
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),

            if (_successMsg != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(_successMsg!, style: const TextStyle(color: Colors.green, fontSize: 12)),
              ),

            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Floor & Type Selectors
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isCompact = constraints.maxWidth < 500;

                        if (isCompact) {
                          return Column(
                            children: [
                              DropdownButtonFormField<String>(
                                initialValue: _selectedFloorId.isNotEmpty ? _selectedFloorId : null,
                                isExpanded: true,
                                decoration: const InputDecoration(labelText: 'Target Floor *'),
                                items: widget.floors.map((f) => DropdownMenuItem(value: f.id, child: Text(f.name, style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis))).toList(),
                                onChanged: (v) => setState(() => _selectedFloorId = v ?? _selectedFloorId),
                              ),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String>(
                                initialValue: _roomType,
                                isExpanded: true,
                                decoration: const InputDecoration(labelText: 'Room Type'),
                                items: _roomTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis))).toList(),
                                onChanged: (v) => setState(() => _roomType = v ?? _roomType),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _capacityCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Default Capacity', hintText: '40'),
                              ),
                            ],
                          );
                        } else {
                          return Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _selectedFloorId.isNotEmpty ? _selectedFloorId : null,
                                  isExpanded: true,
                                  decoration: const InputDecoration(labelText: 'Target Floor *'),
                                  items: widget.floors.map((f) => DropdownMenuItem(value: f.id, child: Text(f.name, style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis))).toList(),
                                  onChanged: (v) => setState(() => _selectedFloorId = v ?? _selectedFloorId),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  initialValue: _roomType,
                                  isExpanded: true,
                                  decoration: const InputDecoration(labelText: 'Room Type'),
                                  items: _roomTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis))).toList(),
                                  onChanged: (v) => setState(() => _roomType = v ?? _roomType),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: _capacityCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(labelText: 'Default Capacity', hintText: '40'),
                                ),
                              ),
                            ],
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 14),

                    // Multiple room numbers input
                    TextField(
                      controller: _roomNumbersCtrl,
                      maxLines: 2,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Room Numbers (comma or newline separated)',
                        hintText: 'e.g. 501, 502, 503, 504, 505',
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${nums.length} room(s) will be generated: ${nums.join(', ')}',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF2563EB), fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),

                    // Common Facilities
                    const Text('Common Facilities / Standard Fixtures:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: _facilitiesList.map((fac) {
                        final isSelected = _selectedFacilities.contains(fac);
                        return FilterChip(
                          label: Text(fac, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87))),
                          selected: isSelected,
                          selectedColor: const Color(0xFF2563EB),
                          checkmarkColor: Colors.white,
                          onSelected: (val) {
                            setState(() {
                              if (val) {
                                _selectedFacilities.add(fac);
                              } else {
                                _selectedFacilities.remove(fac);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                  ),
                  child: _isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Generate ${nums.length} Rooms'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
