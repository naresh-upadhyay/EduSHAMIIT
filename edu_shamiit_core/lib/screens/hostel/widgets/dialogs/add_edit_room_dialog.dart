import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/hostel_models.dart';
import '../../providers/hostel_provider.dart';
import '../../services/hostel_lookup_helper.dart';

class AddEditRoomDialog extends ConsumerStatefulWidget {
  final HostelBuilding? defaultBuilding;
  final HostelFloor? defaultFloor;
  final String? preselectedBuildingId;
  final String? preselectedFloorId;
  final HostelRoomItem? room;
  final HostelRoomItem? roomItem;
  final HostelRoomDetail? roomDetail;
  final HostelTreeRoom? treeRoom;

  const AddEditRoomDialog({
    super.key,
    this.defaultBuilding,
    this.defaultFloor,
    this.preselectedBuildingId,
    this.preselectedFloorId,
    this.room,
    this.roomItem,
    this.roomDetail,
    this.treeRoom,
  });

  @override
  ConsumerState<AddEditRoomDialog> createState() => _AddEditRoomDialogState();
}

class _AddEditRoomDialogState extends ConsumerState<AddEditRoomDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedBuildingId;
  String? _selectedFloorId;
  late TextEditingController _roomNumberController;
  late TextEditingController _roomNameController;
  late TextEditingController _capacityController;
  late TextEditingController _roomSizeController;
  late TextEditingController _monthlyFeeController;
  late TextEditingController _notesController;

  String _roomType = 'Standard';
  String _status = 'Available';
  String _genderRestriction = 'BOYS';
  bool _attachedWashroom = true;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  bool _isLoadingLookups = true;

  List<String> _roomTypes = [];
  List<String> _statusList = [];
  List<HostelLookupItem> _genderItems = [];
  List<String> _photos = [];

  @override
  void initState() {
    super.initState();
    final tr = widget.treeRoom;
    final r = widget.roomDetail;
    final it = widget.room ?? widget.roomItem;

    _selectedBuildingId = widget.preselectedBuildingId ?? widget.defaultBuilding?.id ?? r?.buildingId ?? it?.buildingId;
    _selectedFloorId = widget.preselectedFloorId ?? widget.defaultFloor?.id ?? r?.floorId ?? it?.floorId;

    _roomNumberController = TextEditingController(text: r?.roomNumber ?? it?.roomNumber ?? tr?.roomNumber ?? '');
    _roomNameController = TextEditingController(text: r?.roomName ?? '');
    _capacityController = TextEditingController(text: '${r?.capacity ?? it?.capacity ?? tr?.capacity ?? 3}');
    _roomSizeController = TextEditingController(text: '${r?.roomSizeSqM ?? 18.0}');
    _monthlyFeeController = TextEditingController(text: '${r?.monthlyFee.toInt() ?? 6000}');
    _notesController = TextEditingController(text: r?.notes ?? '');

    _roomType = r?.roomType ?? it?.roomType ?? tr?.roomType ?? 'Standard';
    _status = _normalizeStatus(r?.status ?? it?.status ?? tr?.status);
    _genderRestriction = _normalizeGender(r?.genderRestriction ?? it?.genderRestriction);
    _attachedWashroom = r?.attachedWashroom ?? true;
    _photos = List<String>.from(r?.photos ?? it?.photos ?? []);

    _loadLookups();
  }

  Future<void> _loadLookups() async {
    try {
      final types = await HostelLookupHelper.instance.getActiveLookup('ROOM_TYPE');
      final statuses = await HostelLookupHelper.instance.getActiveLookup('ROOM_STATUS');
      final genders = await HostelLookupHelper.instance.getActiveLookup('HOSTEL_GENDER_POLICY');

      if (mounted) {
        setState(() {
          _roomTypes = types.map((e) => e.label).toList();
          _statusList = statuses.map((e) => e.label).toList();
          _genderItems = genders;

          if (_roomTypes.isNotEmpty && !_roomTypes.contains(_roomType)) {
            _roomTypes.insert(0, _roomType);
          }
          if (_statusList.isNotEmpty && !_statusList.contains(_status)) {
            _statusList.insert(0, _status);
          }

          _isLoadingLookups = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _roomTypes = [
            'Standard', 'Deluxe', 'Super Deluxe', 'Dormitory', 'Single Occupancy',
            'Study Room', 'Toilet/Washroom', 'Common Room / Lounge', 'Mess / Dining Hall',
            'Warden Office', 'Medical / Sick Bay', 'Laundry Room'
          ];
          _statusList = ['Available', 'Occupied', 'Maintenance', 'Reserved', 'Operational'];
          _isLoadingLookups = false;
        });
      }
    }
  }

  String _normalizeStatus(String? s) {
    if (s == null || s.trim().isEmpty) return 'Available';
    final lower = s.trim().toLowerCase();
    if (lower == 'available') return 'Available';
    if (lower == 'occupied') return 'Occupied';
    if (lower == 'maintenance') return 'Maintenance';
    if (lower == 'under repair' || lower == 'under_repair') return 'Under Repair';
    if (lower == 'operational') return 'Operational';
    if (lower == 'out of service' || lower == 'out_of_service') return 'Out of Service';
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  String _normalizeGender(String? g) {
    if (g == null || g.trim().isEmpty) return 'BOYS';
    final upper = g.trim().toUpperCase();
    if (upper == 'GIRLS' || upper == 'FEMALE' || upper == 'GIRL') return 'GIRLS';
    if (upper == 'ANY' || upper == 'COED' || upper == 'CO-ED') return 'COED';
    if (upper == 'STAFF') return 'STAFF';
    return 'BOYS';
  }

  @override
  void dispose() {
    _roomNumberController.dispose();
    _roomNameController.dispose();
    _capacityController.dispose();
    _roomSizeController.dispose();
    _monthlyFeeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _isNonResidential {
    final lower = _roomType.toLowerCase();
    return lower.contains('toilet') ||
        lower.contains('washroom') ||
        lower.contains('storage') ||
        lower.contains('common') ||
        lower.contains('study') ||
        lower.contains('office') ||
        lower.contains('mess') ||
        lower.contains('laundry') ||
        lower.contains('medical') ||
        lower.contains('bay');
  }

  Future<void> _pickAndUploadPhoto() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        if (mounted) {
          ref.read(hostelProvider.notifier).showError('Could not read image file.');
        }
        return;
      }

      setState(() => _isUploadingPhoto = true);
      final roomId = widget.roomDetail?.id ?? widget.roomItem?.id ?? widget.room?.id ?? widget.treeRoom?.id;
      final notifier = ref.read(hostelProvider.notifier);

      final url = await notifier.service.uploadRoomPhoto(
        bytes: bytes,
        filename: file.name,
        roomId: roomId,
      );

      if (mounted) {
        setState(() {
          _photos.add(url);
        });
        notifier.showSuccess('Photo added');
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceAll(RegExp(r'^(ApiException:|Exception:|\s*Api)+', caseSensitive: false), '').trim();
        ref.read(hostelProvider.notifier).showError(msg.isNotEmpty ? msg : 'Error uploading photo');
      }
    } finally {
      if (mounted) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hostelProvider);
    final notifier = ref.read(hostelProvider.notifier);
    final isEditing = widget.roomItem != null || widget.roomDetail != null || widget.room != null || widget.treeRoom != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final buildings = state.structureTree;
    if (_selectedBuildingId == null && buildings.isNotEmpty) {
      _selectedBuildingId = buildings.first.id;
    }

    final currentBuilding = buildings.firstWhere(
      (b) => b.id == _selectedBuildingId,
      orElse: () => buildings.isNotEmpty
          ? buildings.first
          : HostelBuilding(id: '', code: '', name: '', hostelName: '', genderPolicy: '', floorsCount: 0, status: '', floors: []),
    );

    final floors = currentBuilding.floors;
    if ((_selectedFloorId == null || !floors.any((f) => f.id == _selectedFloorId)) && floors.isNotEmpty) {
      _selectedFloorId = floors.first.id;
    }

    final currentTypes = _roomTypes.isNotEmpty
        ? _roomTypes
        : ['Standard', 'Deluxe', 'Super Deluxe', 'Dormitory', 'Single Occupancy', 'Study Room', 'Toilet/Washroom'];

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            isEditing ? 'Edit Room / Space' : 'Add Room / Space',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
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
        width: 540,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Building & Floor
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AppSearchableDropdownFormField<String>.fromMenuItems(
                        isExpanded: true,
                        initialValue: buildings.any((b) => b.id == _selectedBuildingId)
                            ? _selectedBuildingId
                            : (buildings.isNotEmpty ? buildings.first.id : null),
                        decoration: const InputDecoration(labelText: 'Building *'),
                        items: buildings.map((b) => DropdownMenuItem(value: b.id, child: Text(b.name, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: isEditing
                            ? null
                            : (v) {
                                setState(() {
                                  _selectedBuildingId = v;
                                  _selectedFloorId = null;
                                });
                              },
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppSearchableDropdownFormField<String>.fromMenuItems(
                        isExpanded: true,
                        initialValue: floors.any((f) => f.id == _selectedFloorId)
                            ? _selectedFloorId
                            : (floors.isNotEmpty ? floors.first.id : null),
                        decoration: const InputDecoration(labelText: 'Floor *'),
                        items: floors.map((f) => DropdownMenuItem(value: f.id, child: Text(f.name, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: isEditing ? null : (v) => setState(() => _selectedFloorId = v),
                        validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Room Number & Room Type
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _roomNumberController,
                        decoration: const InputDecoration(labelText: 'Room Number *', hintText: 'A-101'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: AppSearchableDropdownFormField<String>.fromMenuItems(
                        isExpanded: true,
                        initialValue: currentTypes.contains(_roomType) ? _roomType : currentTypes.first,
                        decoration: const InputDecoration(
                          labelText: 'Room Type *',
                          helperText: 'From Lookup Management (ROOM_TYPE)',
                        ),
                        items: currentTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (v) {
                          setState(() {
                            _roomType = v ?? 'Standard';
                            if (_isNonResidential) {
                              _status = 'Operational';
                              _capacityController.text = '0';
                            } else {
                              if (_status == 'Operational') _status = 'Available';
                              if (_capacityController.text == '0') _capacityController.text = '3';
                            }
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Capacity & Fee (if residential)
                if (!_isNonResidential) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _capacityController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Capacity (Beds) *', hintText: '3'),
                          validator: (v) => (v == null || int.tryParse(v) == null) ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _monthlyFeeController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Monthly Fee (₹)', hintText: '6000'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],

                // Room Size & Operational Status
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _roomSizeController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Room Size (sq.m)', hintText: '18.0'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Builder(builder: (context) {
                        final currentStatusList = _isNonResidential
                            ? ['Operational', 'Maintenance', 'Out of Service']
                            : (_statusList.isNotEmpty
                                ? _statusList
                                : ['Available', 'Occupied', 'Maintenance', 'Under Repair', 'Operational']);
                        final safeStatus = currentStatusList.firstWhere(
                          (s) => s.toLowerCase() == _status.toLowerCase(),
                          orElse: () => currentStatusList.first,
                        );
                        return AppSearchableDropdownFormField<String>.fromMenuItems(
                          isExpanded: true,
                          initialValue: safeStatus,
                          decoration: const InputDecoration(labelText: 'Operational Status'),
                          items: currentStatusList
                              .map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: (v) => setState(() => _status = v ?? 'Available'),
                        );
                      }),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Gender Restriction & Attached Washroom
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Builder(builder: (context) {
                        final items = _genderItems.isNotEmpty
                            ? _genderItems
                            : const [
                                HostelLookupItem(id: '1', code: 'BOYS', label: 'Boys Only'),
                                HostelLookupItem(id: '2', code: 'GIRLS', label: 'Girls Only'),
                                HostelLookupItem(id: '3', code: 'COED', label: 'Co-Ed'),
                              ];
                        final safeCode = items.any((g) => g.code == _genderRestriction)
                            ? _genderRestriction
                            : items.first.code;

                        return AppSearchableDropdownFormField<String>.fromMenuItems(
                          isExpanded: true,
                          initialValue: safeCode,
                          decoration: const InputDecoration(labelText: 'Gender Restriction'),
                          items: items
                              .map((g) => DropdownMenuItem(value: g.code, child: Text(g.label, overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: (v) => setState(() => _genderRestriction = v ?? 'BOYS'),
                        );
                      }),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Attached Washroom', style: TextStyle(fontSize: 13)),
                        value: _attachedWashroom,
                        onChanged: (v) => setState(() => _attachedWashroom = v ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Notes / Description
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes / Description',
                    hintText: 'e.g. Near staircase, corner room, quiet zone...',
                  ),
                ),
                const SizedBox(height: 14),

                // Photos Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Room Photos (${_photos.length})',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    TextButton.icon(
                      onPressed: _isUploadingPhoto ? null : _pickAndUploadPhoto,
                      icon: _isUploadingPhoto
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add_photo_alternate_outlined, size: 15),
                      label: Text(_isUploadingPhoto ? 'Uploading...' : 'Add Photo'),
                    ),
                  ],
                ),
                if (_photos.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 64,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _photos.length,
                      separatorBuilder: (ctx, i) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            Container(
                              width: 76,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.network(
                                _photos[index],
                                fit: BoxFit.cover,
                                errorBuilder: (ctx, err, stack) => Container(
                                  color: Colors.grey.shade200,
                                  child: const Icon(Icons.broken_image, size: 18),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () => setState(() => _photos.removeAt(index)),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(2),
                                  child: const Icon(Icons.close, size: 12, color: Colors.white),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving
              ? null
              : () async {
                  if (!_formKey.currentState!.validate()) return;
                  setState(() => _isSaving = true);

                  final roomId = widget.roomDetail?.id ?? widget.roomItem?.id ?? widget.room?.id ?? widget.treeRoom?.id;
                  final data = {
                    if (roomId != null) 'id': roomId,
                    'building_id': _selectedBuildingId,
                    'floor_id': _selectedFloorId,
                    'room_number': _roomNumberController.text.trim(),
                    'room_code': _roomNumberController.text.trim(),
                    'room_name': _roomNameController.text.trim().isNotEmpty
                        ? _roomNameController.text.trim()
                        : _roomNumberController.text.trim(),
                    'room_type': _roomType,
                    'is_residential': !_isNonResidential,
                    'capacity': _isNonResidential ? 0 : (int.tryParse(_capacityController.text) ?? 1),
                    'room_size_sqm': double.tryParse(_roomSizeController.text) ?? 18.0,
                    'monthly_fee': double.tryParse(_monthlyFeeController.text) ?? 0.0,
                    'operational_status': _status.toUpperCase().replaceAll(' ', '_'),
                    'status': _status.toUpperCase().replaceAll(' ', '_'),
                    'attached_washroom': _attachedWashroom,
                    'gender_restriction': _genderRestriction,
                    'notes': _notesController.text.trim(),
                    'photos': _photos,
                  };

                  final navigator = Navigator.of(context);
                  try {
                    final res = await notifier.service.saveRoom(data);
                    if (mounted) {
                      if (res['success'] == true) {
                        navigator.pop();
                        notifier.showSuccess(isEditing ? 'Room updated successfully' : 'Room created successfully');
                        notifier.refreshAll();
                      } else {
                        notifier.showError(res['message']?.toString() ?? 'Failed to save room');
                      }
                    }
                  } catch (e) {
                    if (mounted) {
                      final msg = e
                          .toString()
                          .replaceAll(RegExp(r'^(ApiException:|Exception:|\s*Api)+', caseSensitive: false), '')
                          .trim();
                      notifier.showError(msg.isNotEmpty ? msg : 'Error saving room');
                    }
                  } finally {
                    if (mounted) {
                      setState(() => _isSaving = false);
                    }
                  }
                },
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(isEditing ? 'Update Room' : 'Create Room'),
        ),
      ],
    );
  }
}
