import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/hostel_models.dart';
import '../../providers/hostel_provider.dart';
import '../../services/hostel_lookup_helper.dart';

class AddEditBedDialog extends ConsumerStatefulWidget {
  final String roomId;
  final String roomNumber;
  final HostelBed? bed;

  const AddEditBedDialog({
    super.key,
    required this.roomId,
    this.roomNumber = '',
    this.bed,
  });

  @override
  ConsumerState<AddEditBedDialog> createState() => _AddEditBedDialogState();
}

class _AddEditBedDialogState extends ConsumerState<AddEditBedDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _numberController;
  late TextEditingController _codeController;
  late TextEditingController _priceController;
  String _bedType = 'Single';
  String _status = 'Available';
  bool _isSaving = false;
  bool _isDeleting = false;
  bool _isLoadingLookups = true;

  List<String> _bedTypes = [];
  List<String> _bedStatuses = [];

  String _normalizeBedStatus(String? s) {
    if (s == null || s.trim().isEmpty) return 'Available';
    final l = s.trim().toLowerCase();
    if (l == 'available') return 'Available';
    if (l == 'occupied') return 'Occupied';
    if (l == 'reserved') return 'Reserved';
    if (l == 'maintenance') return 'Maintenance';
    if (l == 'blocked') return 'Blocked';
    return 'Available';
  }

  String _normalizeBedType(String? t) {
    if (t == null || t.trim().isEmpty) return 'Single';
    final l = t.trim().toLowerCase();
    if (l.contains('upper')) return 'Bunk Bed (Upper)';
    if (l.contains('lower')) return 'Bunk Bed (Lower)';
    if (l.contains('double')) return 'Double Bed';
    if (l.contains('single')) return 'Single Bed';
    return t;
  }

  @override
  void initState() {
    super.initState();
    final b = widget.bed;
    _numberController = TextEditingController(text: b?.bedNumber ?? 'Bed 1');
    _codeController = TextEditingController(text: b?.bedCode ?? 'B1');
    _priceController = TextEditingController(text: '${b?.monthlyPrice?.toInt() ?? 6000}');
    _bedType = _normalizeBedType(b?.bedType);
    _status = _normalizeBedStatus(b?.status);

    _loadLookups();
  }

  Future<void> _loadLookups() async {
    try {
      final types = await HostelLookupHelper.instance.getActiveLookup('HOSTEL_BED_TYPE');
      final statuses = await HostelLookupHelper.instance.getActiveLookup('ROOM_STATUS');

      if (mounted) {
        setState(() {
          _bedTypes = types.map((e) => e.label).toList();
          _bedStatuses = statuses.map((e) => e.label).toList();

          if (_bedTypes.isNotEmpty && !_bedTypes.contains(_bedType)) {
            final match = _bedTypes.firstWhere(
              (t) => t.toLowerCase().contains(_bedType.toLowerCase()),
              orElse: () => _bedTypes.first,
            );
            _bedType = match;
          }
          if (_bedStatuses.isNotEmpty && !_bedStatuses.contains(_status)) {
            final match = _bedStatuses.firstWhere(
              (s) => s.toLowerCase() == _status.toLowerCase(),
              orElse: () => _bedStatuses.first,
            );
            _status = match;
          }

          _isLoadingLookups = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _bedTypes = ['Single Bed', 'Bunk Bed (Lower)', 'Bunk Bed (Upper)', 'Double Bed'];
          _bedStatuses = ['Available', 'Occupied', 'Reserved', 'Maintenance', 'Blocked'];
          _isLoadingLookups = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _numberController.dispose();
    _codeController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _deleteBed() async {
    final b = widget.bed;
    if (b == null || b.id.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Bed'),
        content: Text('Are you sure you want to delete ${b.bedNumberOrCode} from this room?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);
    final notifier = ref.read(hostelProvider.notifier);
    final navigator = Navigator.of(context);

    try {
      final ok = await notifier.service.deleteBed(b.id);
      if (mounted) {
        if (ok) {
          navigator.pop();
          notifier.showSuccess('Bed removed successfully');
          notifier.fetchRoomDetail(widget.roomId);
          notifier.fetchRooms();
        } else {
          notifier.showError('Could not delete bed');
        }
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceAll(RegExp(r'^(ApiException:|Exception:|\s*Api)+', caseSensitive: false), '').trim();
        notifier.showError(msg.isNotEmpty ? msg : 'Error deleting bed');
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
    final isEditing = widget.bed != null;

    final types = _bedTypes.isNotEmpty
        ? _bedTypes
        : ['Single Bed', 'Bunk Bed (Lower)', 'Bunk Bed (Upper)', 'Double Bed'];
    final safeBedType = types.contains(_bedType) ? _bedType : types.first;

    final statuses = _bedStatuses.isNotEmpty
        ? _bedStatuses
        : ['Available', 'Occupied', 'Reserved', 'Maintenance', 'Blocked'];
    final safeStatus = statuses.contains(_status) ? _status : statuses.first;

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(isEditing ? 'Edit Bed (${widget.roomNumber})' : 'Add Bed to Room ${widget.roomNumber}'),
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
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _numberController,
                      decoration: const InputDecoration(labelText: 'Bed Label *', hintText: 'Bed 1'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _codeController,
                      decoration: const InputDecoration(labelText: 'Bed Code *', hintText: 'B1'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppSearchableDropdownFormField<String>.fromMenuItems(
                      isExpanded: true,
                      initialValue: safeBedType,
                      decoration: const InputDecoration(labelText: 'Bed Type'),
                      items: types.map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (v) => setState(() => _bedType = v ?? 'Single Bed'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppSearchableDropdownFormField<String>.fromMenuItems(
                      isExpanded: true,
                      initialValue: safeStatus,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: statuses.map((s) => DropdownMenuItem(value: s, child: Text(s, overflow: TextOverflow.ellipsis))).toList(),
                      onChanged: (v) => setState(() => _status = v ?? 'Available'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Monthly Price (₹)', hintText: '6000'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (isEditing)
          TextButton.icon(
            onPressed: (_isSaving || _isDeleting) ? null : _deleteBed,
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

                  final data = {
                    if (widget.bed != null) 'id': widget.bed!.id,
                    'room_id': widget.roomId,
                    'bed_number': _numberController.text.trim(),
                    'bed_code': _codeController.text.trim(),
                    'bed_type': _bedType,
                    'monthly_fee': double.tryParse(_priceController.text) ?? 6000.0,
                    'monthly_price': double.tryParse(_priceController.text) ?? 6000.0,
                    'status': _status.toUpperCase(),
                  };

                  final navigator = Navigator.of(context);
                  try {
                    final res = await notifier.service.saveBed(data);
                    if (mounted) {
                      if (res['success'] == true) {
                        navigator.pop();
                        notifier.showSuccess(isEditing ? 'Bed updated successfully' : 'Bed created successfully');
                        notifier.fetchRoomDetail(widget.roomId);
                        notifier.fetchRooms();
                      } else {
                        notifier.showError(res['message']?.toString() ?? 'Failed to save bed');
                      }
                    }
                  } catch (e) {
                    if (mounted) {
                      final msg = e
                          .toString()
                          .replaceAll(RegExp(r'^(ApiException:|Exception:|\s*Api)+', caseSensitive: false), '')
                          .trim();
                      notifier.showError(msg.isNotEmpty ? msg : 'Error saving bed');
                    }
                  } finally {
                    if (mounted) {
                      setState(() => _isSaving = false);
                    }
                  }
                },
          child: _isSaving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(isEditing ? 'Update Bed' : 'Create Bed'),
        ),
      ],
    );
  }
}
