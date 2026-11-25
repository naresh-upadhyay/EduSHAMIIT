import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/hostel_models.dart';
import '../../providers/hostel_provider.dart';
import '../../services/hostel_lookup_helper.dart';

class AddEquipmentDialog extends ConsumerStatefulWidget {
  final String roomId;
  final String roomNumber;
  final HostelEquipment? equipment;

  const AddEquipmentDialog({
    super.key,
    required this.roomId,
    this.roomNumber = '',
    this.equipment,
  });

  @override
  ConsumerState<AddEquipmentDialog> createState() => _AddEquipmentDialogState();
}

class _AddEquipmentDialogState extends ConsumerState<AddEquipmentDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _qtyController;
  late TextEditingController _assetTagController;
  late TextEditingController _notesController;
  String _condition = 'Good';
  bool _isCritical = false;
  bool _isSaving = false;
  bool _isDeleting = false;
  bool _isLoadingLookups = true;

  List<String> _facilityNames = [];
  List<String> _conditionNames = [];

  @override
  void initState() {
    super.initState();
    final eq = widget.equipment;
    final initialName = eq?.name ?? '';
    _nameController = TextEditingController(text: initialName);
    _qtyController = TextEditingController(text: '${eq?.quantity ?? 1}');
    _assetTagController = TextEditingController(text: eq?.assetTag ?? '');
    _notesController = TextEditingController(text: eq?.notes ?? '');
    _condition = _normalizeCondition(eq?.condition ?? eq?.status);
    _isCritical = eq?.isCritical ?? false;

    _loadLookups();
  }

  Future<void> _loadLookups() async {
    try {
      final facilities = await HostelLookupHelper.instance.getActiveLookup('ROOM_FACILITY');
      final conditions = await HostelLookupHelper.instance.getActiveLookup('FACILITY_CONDITION');
      
      if (mounted) {
        setState(() {
          _facilityNames = facilities.map((e) => e.label).toList();
          _conditionNames = conditions.map((e) => e.label).toList();

          if (_conditionNames.isEmpty) {
            _conditionNames = ['Good', 'Working', 'Faulty', 'Under Repair', 'Not Available', 'Out of Service'];
          }

          // Ensure current name is in list
          if (_nameController.text.isNotEmpty && !_facilityNames.contains(_nameController.text)) {
            _facilityNames.insert(0, _nameController.text);
          } else if (_nameController.text.isEmpty && _facilityNames.isNotEmpty) {
            _nameController.text = _facilityNames.first;
          }

          // Ensure condition is in list
          if (!_conditionNames.contains(_condition)) {
            final match = _conditionNames.firstWhere(
              (c) => c.toLowerCase() == _condition.toLowerCase(),
              orElse: () => _conditionNames.first,
            );
            _condition = match;
          }

          _isLoadingLookups = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _facilityNames = [
            'Western Toilet', 'Urinal', 'Wash Basin', 'Shower', 'Geyser', 'Mirror',
            'Exhaust Fan', 'Water Tap', 'Hand Dryer', 'Liquid Soap Dispenser', 'Towel Rail',
            'Beds', 'Fans', 'AC', 'WiFi', 'Study Table', 'Wardrobe', 'Attached Washroom',
            'Power Outlets', 'Lighting', 'Balcony', 'Television', 'Housekeeping',
            'Water Purifier', 'First Aid Kit', 'Fire Extinguisher'
          ];
          _conditionNames = ['Good', 'Working', 'Faulty', 'Under Repair', 'Not Available', 'Out of Service'];
          if (_nameController.text.isEmpty) {
            _nameController.text = _facilityNames.first;
          }
          _isLoadingLookups = false;
        });
      }
    }
  }

  String _normalizeCondition(String? c) {
    if (c == null || c.trim().isEmpty) return 'Good';
    final l = c.trim().toLowerCase();
    if (l == 'good') return 'Good';
    if (l == 'working') return 'Working';
    if (l == 'faulty') return 'Faulty';
    if (l == 'under repair' || l == 'under_repair') return 'Under Repair';
    if (l == 'not available' || l == 'not_available') return 'Not Available';
    if (l == 'out of service' || l == 'out_of_service') return 'Out of Service';
    return 'Good';
  }

  String _detectCategory(String name) {
    final l = name.toLowerCase();
    if (l.contains('toilet') || l.contains('urinal') || l.contains('basin') || 
        l.contains('shower') || l.contains('tap') || l.contains('geyser') || 
        l.contains('washroom') || l.contains('soap') || l.contains('towel')) {
      return 'PLUMBING_SANITARY';
    }
    if (l.contains('fan') || l.contains('ac') || l.contains('light') || 
        l.contains('outlet') || l.contains('wifi') || l.contains('tv') || 
        l.contains('dryer')) {
      return 'ELECTRICAL';
    }
    if (l.contains('bed') || l.contains('table') || l.contains('wardrobe') || 
        l.contains('chair') || l.contains('desk') || l.contains('mirror')) {
      return 'FURNITURE';
    }
    if (l.contains('extinguisher') || l.contains('first aid') || l.contains('detector') || l.contains('safety')) {
      return 'SAFETY';
    }
    return 'GENERAL';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _qtyController.dispose();
    _assetTagController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _deleteEquipment() async {
    final eq = widget.equipment;
    if (eq == null || eq.id.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Facility / Equipment'),
        content: Text('Are you sure you want to remove "${eq.name}" from room ${widget.roomNumber}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isDeleting = true);
    final notifier = ref.read(hostelProvider.notifier);
    final navigator = Navigator.of(context);

    try {
      final ok = await notifier.service.deleteEquipment(eq.id);
      if (mounted) {
        if (ok) {
          navigator.pop();
          notifier.showSuccess('Facility removed successfully');
          notifier.fetchRoomDetail(widget.roomId);
          notifier.fetchRooms();
        } else {
          notifier.showError('Failed to delete facility');
        }
      }
    } catch (e) {
      if (mounted) {
        notifier.showError('Error deleting facility: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(hostelProvider.notifier);
    final isEditing = widget.equipment != null;

    final items = _facilityNames.toList();
    if (_nameController.text.isNotEmpty && !items.contains(_nameController.text)) {
      items.insert(0, _nameController.text);
    }

    final safeCondition = _conditionNames.contains(_condition)
        ? _condition
        : (_conditionNames.isNotEmpty ? _conditionNames.first : 'Good');

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            isEditing
                ? 'Edit Facility (${widget.roomNumber})'
                : 'Add Facility / Equipment (${widget.roomNumber})',
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
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppSearchableDropdownFormField<String>.fromMenuItems(
                  isExpanded: true,
                  initialValue: items.contains(_nameController.text)
                      ? _nameController.text
                      : (items.isNotEmpty ? items.first : null),
                  decoration: const InputDecoration(
                    labelText: 'Facility / Equipment Name *',
                    helperText: 'Dynamically populated from Lookup Management (ROOM_FACILITY)',
                  ),
                  items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      setState(() => _nameController.text = v);
                    }
                  },
                  validator: (v) => _nameController.text.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _qtyController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Quantity *'),
                        validator: (v) => (v == null || int.tryParse(v) == null || int.parse(v) < 1)
                            ? 'Min 1'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppSearchableDropdownFormField<String>.fromMenuItems(
                        isExpanded: true,
                        initialValue: safeCondition,
                        decoration: const InputDecoration(labelText: 'Condition / Status *'),
                        items: _conditionNames
                            .map((c) => DropdownMenuItem(value: c, child: Text(c, overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: (v) => setState(() => _condition = v ?? 'Good'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _assetTagController,
                  decoration: const InputDecoration(
                    labelText: 'Asset Code / Serial No',
                    hintText: 'EQ-AST-0092',
                  ),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Critical for Room Operation', style: TextStyle(fontSize: 13)),
                  subtitle: const Text(
                    'If faulty, flags the room for maintenance inspection',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  value: _isCritical,
                  onChanged: (v) => setState(() => _isCritical = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Notes / Maintenance info',
                    hintText: 'e.g. Brand, warranty date, specific location in room...',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (isEditing)
          TextButton.icon(
            onPressed: (_isSaving || _isDeleting) ? null : _deleteEquipment,
            icon: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
            label: _isDeleting
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFEF4444)),
                  )
                : const Text('Delete', style: TextStyle(color: Color(0xFFEF4444))),
          ),
        const Spacer(),
        TextButton(
          onPressed: (_isSaving || _isDeleting) ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: (_isSaving || _isDeleting)
              ? null
              : () async {
                  if (!_formKey.currentState!.validate()) return;
                  setState(() => _isSaving = true);

                  final eqName = _nameController.text.trim();
                  final data = {
                    if (widget.equipment != null) 'id': widget.equipment!.id,
                    'room_id': widget.roomId,
                    'name': eqName,
                    'equipment_name': eqName,
                    'equipment_category': _detectCategory(eqName),
                    'quantity': int.tryParse(_qtyController.text) ?? 1,
                    'operating_condition': _condition,
                    'status': _condition,
                    'asset_tag': _assetTagController.text.trim(),
                    'asset_code': _assetTagController.text.trim(),
                    'is_critical': _isCritical,
                    'notes': _notesController.text.trim(),
                  };

                  final navigator = Navigator.of(context);
                  try {
                    final res = await notifier.service.saveEquipment(data);
                    if (mounted) {
                      if (res['success'] == true) {
                        navigator.pop();
                        notifier.showSuccess(isEditing ? 'Facility updated successfully' : 'Facility added successfully');
                        notifier.fetchRoomDetail(widget.roomId);
                        notifier.fetchRooms();
                      } else {
                        notifier.showError(res['message']?.toString() ?? 'Failed to save facility');
                      }
                    }
                  } catch (e) {
                    if (mounted) {
                      final msg = e
                          .toString()
                          .replaceAll(RegExp(r'^(ApiException:|Exception:|\s*Api)+', caseSensitive: false), '')
                          .trim();
                      notifier.showError(msg.isNotEmpty ? msg : 'Error saving facility');
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
              : Text(isEditing ? 'Update Facility' : 'Save Facility'),
        ),
      ],
    );
  }
}
