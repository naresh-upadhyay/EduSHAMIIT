import 'package:edu_shamiit_core/widgets/dropdowns/dropdowns.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../models/campus_models.dart';
import '../../services/campus_api_service.dart';
import '../../services/campus_lookup_helper.dart';

class RoomAllocationDialog extends StatefulWidget {
  final RoomModel room;
  final VoidCallback onAllocated;

  const RoomAllocationDialog({
    super.key,
    required this.room,
    required this.onAllocated,
  });

  @override
  State<RoomAllocationDialog> createState() => _RoomAllocationDialogState();
}

class _RoomAllocationDialogState extends State<RoomAllocationDialog> {
  final _formKey = GlobalKey<FormState>();

  String _referenceModule = 'Academics';
  final _refNameCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController(text: 'Daily Class Instruction');
  final _assignedToCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  bool _isSaving = false;
  String? _error;

  List<String> _modules = [
    'Academics', 'Timetable', 'Examinations', 'Hostel', 'Library',
    'Transport', 'Administration', 'Sports', 'Other'
  ];
  List<Map<String, dynamic>> _staffUsers = [];
  final _assignedFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadLookups();
  }

  Future<void> _loadLookups() async {
    final mods = await CampusLookupHelper.instance.getLookupLabels(
      'ALLOCATION_MODULE',
      defaultLabels: [
        'Academics', 'Timetable', 'Examinations', 'Hostel', 'Library',
        'Transport', 'Administration', 'Sports', 'Other'
      ],
    );
    final users = await CampusLookupHelper.instance.getStaffUsers();
    if (mounted) {
      setState(() {
        _modules = mods;
        _staffUsers = users;
        if (!_modules.contains(_referenceModule) && _modules.isNotEmpty) {
          _referenceModule = _modules.first;
        }
      });
    }
  }

  @override
  void dispose() {
    _refNameCtrl.dispose();
    _purposeCtrl.dispose();
    _assignedToCtrl.dispose();
    _notesCtrl.dispose();
    _assignedFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSaving = true;
      _error = null;
    });

    final payload = {
      'room_id': widget.room.id,
      'reference_module': _referenceModule,
      'reference_name': _refNameCtrl.text.trim(),
      'purpose': _purposeCtrl.text.trim(),
      'assigned_to_name': _assignedToCtrl.text.trim().isNotEmpty ? _assignedToCtrl.text.trim() : null,
      'notes': _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
    };

    final res = await CampusApiService.instance.allocateRoom(widget.room.id, payload);

    if (mounted) {
      setState(() => _isSaving = false);
      if (res['success'] == true) {
        Navigator.of(context).pop();
        widget.onAllocated();
      } else {
        setState(() => _error = res['message'] ?? 'Failed to allocate room.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final dialogWidth = math.min(480.0, screenWidth * 0.95);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                      const Icon(Icons.group_outlined, color: Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Allocate Room ${widget.room.roomNumber}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.of(context).pop()),
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

            Flexible(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      AppSearchableDropdownFormField<String>.fromMenuItems(
                        initialValue: _referenceModule,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Allocation Module *'),
                        items: _modules.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 12.5), overflow: TextOverflow.ellipsis))).toList(),
                        onChanged: (v) => setState(() => _referenceModule = v ?? _referenceModule),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _refNameCtrl,
                        decoration: const InputDecoration(labelText: 'Target Entity / Section Name *', hintText: 'e.g. Grade 10 - Section A'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _purposeCtrl,
                        decoration: const InputDecoration(labelText: 'Allocation Purpose *', hintText: 'e.g. Daily Class Instruction'),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
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
                        focusNode: _assignedFocusNode,
                        textEditingController: _assignedToCtrl,
                        onSelected: (u) {
                          _assignedToCtrl.text = (u['full_name'] ?? u['username'] ?? '').toString();
                        },
                        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              labelText: 'Assigned Incharge / Teacher Name',
                              hintText: 'Select teacher or staff from User Management',
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
                                width: dialogWidth - 44,
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
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _notesCtrl,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Allocation Notes', hintText: 'Special permissions, usage rules...'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                  child: _isSaving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Confirm Allocation'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
