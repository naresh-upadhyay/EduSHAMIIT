import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/hostel_models.dart';
import '../../providers/hostel_provider.dart';

class AddEditFloorDialog extends ConsumerStatefulWidget {
  final HostelBuilding? defaultBuilding;
  final String? preselectedBuildingId;
  final HostelFloor? floor;

  const AddEditFloorDialog({
    super.key,
    this.defaultBuilding,
    this.preselectedBuildingId,
    this.floor,
  });

  @override
  ConsumerState<AddEditFloorDialog> createState() => _AddEditFloorDialogState();
}

class _AddEditFloorDialogState extends ConsumerState<AddEditFloorDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedBuildingId;
  late TextEditingController _numberController;
  late TextEditingController _nameController;
  late TextEditingController _codeController;
  late TextEditingController _wingController;
  String _status = 'ACTIVE';
  bool _isSaving = false;
  bool _userManuallyEditedName = false;
  bool _userManuallyEditedCode = false;

  @override
  void initState() {
    super.initState();
    final f = widget.floor;
    _selectedBuildingId = widget.preselectedBuildingId ?? widget.defaultBuilding?.id ?? f?.buildingId;

    if (f != null) {
      _numberController = TextEditingController(text: '${f.floorNumber}');
      _nameController = TextEditingController(text: f.floorName);
      _codeController = TextEditingController(text: f.floorCode);
      _wingController = TextEditingController(text: f.wing ?? '');
      _status = f.status;
      _userManuallyEditedName = true;
      _userManuallyEditedCode = true;
    } else {
      // Calculate next available floor number based on building
      final tree = ref.read(hostelProvider).structureTree;
      final bId = _selectedBuildingId ?? (tree.isNotEmpty ? tree.first.id : null);
      _selectedBuildingId = bId;

      int initialNum = 0;
      if (bId != null) {
        final b = tree.where((x) => x.id == bId).firstOrNull;
        if (b != null && b.floors.isNotEmpty) {
          final nums = b.floors.map((fl) => fl.floorNumber).toList();
          nums.sort();
          initialNum = nums.last + 1;
        }
      }

      _numberController = TextEditingController(text: '$initialNum');
      _nameController = TextEditingController();
      _codeController = TextEditingController();
      _wingController = TextEditingController();
      _autoFillName(initialNum);
    }

    _numberController.addListener(_onNumberChanged);
  }

  void _onNumberChanged() {
    if (widget.floor == null) {
      final num = int.tryParse(_numberController.text.trim());
      if (num != null) {
        _autoFillName(num);
      }
    }
  }

  void _autoFillName(int num) {
    if (!_userManuallyEditedName) {
      if (num == 0) {
        _nameController.text = 'Ground Floor';
      } else if (num == 1) {
        _nameController.text = '1st Floor';
      } else if (num == 2) {
        _nameController.text = '2nd Floor';
      } else if (num == 3) {
        _nameController.text = '3rd Floor';
      } else {
        _nameController.text = '${num}th Floor';
      }
    }
    if (!_userManuallyEditedCode) {
      _codeController.text = 'FL-$num';
    }
  }

  void _onBuildingChanged(String? newBuildingId) {
    if (newBuildingId == null || newBuildingId == _selectedBuildingId) return;
    setState(() {
      _selectedBuildingId = newBuildingId;
      if (widget.floor == null) {
        final tree = ref.read(hostelProvider).structureTree;
        final b = tree.where((x) => x.id == newBuildingId).firstOrNull;
        int nextNum = 0;
        if (b != null && b.floors.isNotEmpty) {
          final nums = b.floors.map((fl) => fl.floorNumber).toList();
          nums.sort();
          nextNum = nums.last + 1;
        }
        _numberController.text = '$nextNum';
        _userManuallyEditedName = false;
        _userManuallyEditedCode = false;
        _autoFillName(nextNum);
      }
    });
  }

  @override
  void dispose() {
    _numberController.removeListener(_onNumberChanged);
    _numberController.dispose();
    _nameController.dispose();
    _codeController.dispose();
    _wingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hostelProvider);
    final notifier = ref.read(hostelProvider.notifier);
    final isEditing = widget.floor != null;

    final buildings = state.structureTree;
    if (_selectedBuildingId == null && buildings.isNotEmpty) {
      _selectedBuildingId = buildings.first.id;
    }

    final currentBuilding = buildings.where((b) => b.id == _selectedBuildingId).firstOrNull;

    return AlertDialog(
      title: Text(isEditing ? 'Edit Floor' : 'Add Floor'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: buildings.any((b) => b.id == _selectedBuildingId)
                      ? _selectedBuildingId
                      : (buildings.isNotEmpty ? buildings.first.id : null),
                  decoration: const InputDecoration(labelText: 'Hostel / Building *'),
                  items: buildings.map((b) {
                    return DropdownMenuItem(value: b.id, child: Text(b.name, overflow: TextOverflow.ellipsis));
                  }).toList(),
                  onChanged: isEditing ? null : _onBuildingChanged,
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 1,
                      child: TextFormField(
                        controller: _numberController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Number *', hintText: '0, 1, 2...'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          final num = int.tryParse(v.trim());
                          if (num == null) return 'Invalid number';
                          if (currentBuilding != null) {
                            final duplicate = currentBuilding.floors.any((f) {
                              if (widget.floor != null && f.id == widget.floor!.id) return false;
                              return f.floorNumber == num;
                            });
                            if (duplicate) {
                              return 'Floor $num exists in ${currentBuilding.name}';
                            }
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _codeController,
                        decoration: const InputDecoration(labelText: 'Floor Code *', hintText: 'FL-1'),
                        onChanged: (_) => _userManuallyEditedCode = true,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          final code = v.trim().toUpperCase();
                          if (currentBuilding != null) {
                            final duplicate = currentBuilding.floors.any((f) {
                              if (widget.floor != null && f.id == widget.floor!.id) return false;
                              return f.floorCode.toUpperCase() == code;
                            });
                            if (duplicate) {
                              return 'Code $code already exists';
                            }
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Floor Name / Label *', hintText: '1st Floor'),
                  onChanged: (_) => _userManuallyEditedName = true,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _wingController,
                        decoration: const InputDecoration(labelText: 'Wing / Block', hintText: 'North Wing'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: ['ACTIVE', 'MAINTENANCE', 'INACTIVE'].contains(_status.toUpperCase())
                            ? _status.toUpperCase()
                            : 'ACTIVE',
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: const [
                          DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                          DropdownMenuItem(value: 'MAINTENANCE', child: Text('Maintenance')),
                          DropdownMenuItem(value: 'INACTIVE', child: Text('Inactive')),
                        ],
                        onChanged: (v) => setState(() => _status = v ?? 'ACTIVE'),
                      ),
                    ),
                  ],
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
              if (widget.floor != null) 'id': widget.floor!.id,
              'building_id': _selectedBuildingId,
              'floor_number': int.tryParse(_numberController.text.trim()) ?? 0,
              'floor_name': _nameController.text.trim(),
              'floor_code': _codeController.text.trim(),
              'wing': _wingController.text.trim(),
              'status': _status,
            };

            final navigator = Navigator.of(context);
            try {
              final res = await notifier.service.saveFloor(data);
              if (mounted) {
                if (res['success'] == true) {
                  navigator.pop();
                  notifier.showSuccess(isEditing ? 'Floor updated' : 'Floor created');
                  notifier.refreshAll();
                } else {
                  notifier.showError(res['message']?.toString() ?? 'Failed to save floor');
                }
              }
            } catch (e) {
              if (mounted) {
                final msg = e.toString().replaceAll(RegExp(r'^(ApiException:|Exception:|\s*Api)+', caseSensitive: false), '').trim();
                notifier.showError(msg.isNotEmpty ? msg : 'Error saving floor');
              }
            } finally {
              if (mounted) {
                setState(() => _isSaving = false);
              }
            }
          },
          child: _isSaving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(isEditing ? 'Update Floor' : 'Create Floor'),
        ),
      ],
    );
  }
}
