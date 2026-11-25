import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/hostel_models.dart';
import '../../providers/hostel_provider.dart';
import '../../services/hostel_lookup_helper.dart';

class AddEditBuildingDialog extends ConsumerStatefulWidget {
  final HostelBuilding? building;
  const AddEditBuildingDialog({super.key, this.building});

  @override
  ConsumerState<AddEditBuildingDialog> createState() => _AddEditBuildingDialogState();
}

class _AddEditBuildingDialogState extends ConsumerState<AddEditBuildingDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _codeController;
  late TextEditingController _nameController;
  late TextEditingController _hostelNameController;
  late TextEditingController _floorsController;
  late TextEditingController _descController;
  String _gender = 'BOYS';
  String _status = 'OPERATIONAL';
  bool _isSaving = false;
  bool _isLoadingLookups = true;

  List<HostelLookupItem> _genderItems = [];

  @override
  void initState() {
    super.initState();
    final b = widget.building;
    _codeController = TextEditingController(text: b?.code ?? '');
    _nameController = TextEditingController(text: b?.name ?? '');
    _hostelNameController = TextEditingController(text: b?.hostelName ?? '');
    _floorsController = TextEditingController(text: '${b?.floorsCount ?? 4}');
    _descController = TextEditingController(text: b?.description ?? '');
    _gender = b?.genderPolicy ?? 'BOYS';
    _status = b?.status ?? 'OPERATIONAL';

    _loadLookups();
  }

  Future<void> _loadLookups() async {
    try {
      final items = await HostelLookupHelper.instance.getActiveLookup('HOSTEL_GENDER_POLICY');
      if (mounted) {
        setState(() {
          _genderItems = items;
          _isLoadingLookups = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _genderItems = const [
            HostelLookupItem(id: '1', code: 'BOYS', label: 'Boys Only'),
            HostelLookupItem(id: '2', code: 'GIRLS', label: 'Girls Only'),
            HostelLookupItem(id: '3', code: 'COED', label: 'Co-Ed'),
            HostelLookupItem(id: '4', code: 'STAFF', label: 'Staff Quarters'),
          ];
          _isLoadingLookups = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _hostelNameController.dispose();
    _floorsController.dispose();
    _descController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(hostelProvider.notifier);
    final isEditing = widget.building != null;

    final genderOptions = _genderItems.isNotEmpty
        ? _genderItems
        : const [
            HostelLookupItem(id: '1', code: 'BOYS', label: 'Boys Only'),
            HostelLookupItem(id: '2', code: 'GIRLS', label: 'Girls Only'),
            HostelLookupItem(id: '3', code: 'COED', label: 'Co-Ed'),
            HostelLookupItem(id: '4', code: 'STAFF', label: 'Staff Quarters'),
          ];

    final safeGender = genderOptions.any((g) => g.code.toUpperCase() == _gender.toUpperCase())
        ? _gender.toUpperCase()
        : genderOptions.first.code;

    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(isEditing ? 'Edit Hostel Building' : 'Add Hostel Building'),
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
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _codeController,
                        decoration: const InputDecoration(labelText: 'Code *', hintText: 'BHA'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Building Name *', hintText: 'Boys Hostel A'),
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
                        initialValue: safeGender,
                        decoration: const InputDecoration(labelText: 'Gender Policy'),
                        items: genderOptions
                            .map((g) => DropdownMenuItem(value: g.code, child: Text(g.label, overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: (v) => setState(() => _gender = v ?? 'BOYS'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _floorsController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Floor Count'),
                        validator: (v) => (v == null || int.tryParse(v) == null) ? 'Enter valid number' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Description / Notes', hintText: 'Building location, warden in charge...'),
                ),
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
          onPressed: _isSaving ? null : () async {
            if (!_formKey.currentState!.validate()) return;
            setState(() => _isSaving = true);

            final data = {
              if (widget.building != null) 'id': widget.building!.id,
              'code': _codeController.text.trim(),
              'name': _nameController.text.trim(),
              'hostel_name': _hostelNameController.text.trim().isNotEmpty
                  ? _hostelNameController.text.trim()
                  : _nameController.text.trim(),
              'gender_policy': _gender,
              'total_floors': int.tryParse(_floorsController.text) ?? 1,
              'description': _descController.text.trim(),
              'operational_status': _status,
            };

            final navigator = Navigator.of(context);
            try {
              final res = await notifier.service.saveBuilding(data);
              if (mounted) {
                if (res['success'] == true) {
                  navigator.pop();
                  notifier.showSuccess(isEditing ? 'Building updated' : 'Building created');
                  notifier.refreshAll();
                } else {
                  notifier.showError(res['message']?.toString() ?? 'Failed to save building');
                }
              }
            } catch (e) {
              if (mounted) {
                final msg = e.toString().replaceAll(RegExp(r'^(ApiException:|Exception:|\s*Api)+', caseSensitive: false), '').trim();
                notifier.showError(msg.isNotEmpty ? msg : 'Error saving building');
              }
            } finally {
              if (mounted) {
                setState(() => _isSaving = false);
              }
            }
          },
          child: _isSaving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(isEditing ? 'Update Building' : 'Create Building'),
        ),
      ],
    );
  }
}
