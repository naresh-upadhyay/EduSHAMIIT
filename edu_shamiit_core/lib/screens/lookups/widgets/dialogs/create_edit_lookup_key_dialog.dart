import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/lookup_models.dart';
import '../../providers/lookup_provider.dart';

class CreateEditLookupKeyDialog extends ConsumerStatefulWidget {
  final LookupKeyModel? lookupKey;

  const CreateEditLookupKeyDialog({super.key, this.lookupKey});

  @override
  ConsumerState<CreateEditLookupKeyDialog> createState() => _CreateEditLookupKeyDialogState();
}

class _CreateEditLookupKeyDialogState extends ConsumerState<CreateEditLookupKeyDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _codeController;
  late TextEditingController _descController;
  String _keyType = 'CUSTOM';
  String _status = 'ACTIVE';
  String _selectedIcon = 'folder_outlined';
  bool _autoCode = true;

  final List<Map<String, String>> _initialValues = [];

  final List<Map<String, dynamic>> _iconOptions = [
    {'name': 'folder_outlined', 'icon': Icons.folder_outlined, 'label': 'General'},
    {'name': 'calendar_today_rounded', 'icon': Icons.calendar_today_rounded, 'label': 'Calendar'},
    {'name': 'grid_view_rounded', 'icon': Icons.grid_view_rounded, 'label': 'Modules'},
    {'name': 'directions_bus_rounded', 'icon': Icons.directions_bus_rounded, 'label': 'Transport'},
    {'name': 'people_outline_rounded', 'icon': Icons.people_outline_rounded, 'label': 'Users'},
    {'name': 'description_outlined', 'icon': Icons.description_outlined, 'label': 'Docs'},
    {'name': 'receipt_long_rounded', 'icon': Icons.receipt_long_rounded, 'label': 'Finance'},
    {'name': 'event_busy_rounded', 'icon': Icons.event_busy_rounded, 'label': 'Leave'},
    {'name': 'account_balance_wallet_rounded', 'icon': Icons.account_balance_wallet_rounded, 'label': 'Fees'},
    {'name': 'alt_route_rounded', 'icon': Icons.alt_route_rounded, 'label': 'Routes'},
    {'name': 'flag_rounded', 'icon': Icons.flag_rounded, 'label': 'Priority'},
  ];

  @override
  void initState() {
    super.initState();
    final k = widget.lookupKey;
    _nameController = TextEditingController(text: k?.keyName ?? '');
    _codeController = TextEditingController(text: k?.keyCode ?? '');
    _descController = TextEditingController(text: k?.description ?? '');
    _keyType = k?.keyType ?? 'CUSTOM';
    _status = k?.status ?? 'ACTIVE';
    _selectedIcon = k?.icon ?? 'folder_outlined';
    _autoCode = k == null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _onNameChanged(String val) {
    if (_autoCode && widget.lookupKey == null) {
      final code = val
          .toUpperCase()
          .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
          .replaceAll(RegExp(r'^_+|_+$'), '');
      _codeController.text = code;
    }
  }

  void _addInitialValue() {
    setState(() {
      _initialValues.add({'value_name': '', 'value_code': ''});
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final isEdit = widget.lookupKey != null;
    final payload = <String, dynamic>{
      'key_name': _nameController.text.trim(),
      'description': _descController.text.trim(),
      'icon': _selectedIcon,
      'status': _status,
    };

    if (!isEdit) {
      payload['key_code'] = _codeController.text.trim().toUpperCase();
      payload['key_type'] = _keyType;

      final filteredVals = _initialValues
          .where((v) => v['value_name']!.trim().isNotEmpty)
          .map((v) {
            var code = v['value_code']!.trim().toUpperCase();
            if (code.isEmpty) {
              code = v['value_name']!
                  .trim()
                  .toUpperCase()
                  .replaceAll(RegExp(r'[^A-Z0-9]+'), '_');
            }
            return {
              'value_name': v['value_name']!.trim(),
              'value_code': code,
              'status': 'ACTIVE',
            };
          })
          .toList();

      if (filteredVals.isNotEmpty) {
        payload['initial_values'] = filteredVals;
      }
    }

    bool success;
    if (isEdit) {
      success = await ref.read(lookupProvider.notifier).updateLookupKey(widget.lookupKey!.id, payload);
    } else {
      success = await ref.read(lookupProvider.notifier).createLookupKey(payload);
    }

    if (success && mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEdit ? 'Lookup key updated successfully!' : 'Lookup key created successfully!'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } else if (mounted) {
      final err = ref.read(lookupProvider).errorMessage ?? 'Failed to save lookup key';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEdit = widget.lookupKey != null;
    final state = ref.watch(lookupProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth < 640 ? screenWidth - 32 : 600.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Container(
        width: dialogWidth,
        constraints: const BoxConstraints(maxHeight: 720),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.folder_outlined, color: Color(0xFF4F46E5), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit ? 'Edit Lookup Key' : 'Create Lookup Key',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          isEdit
                              ? 'Update display name, description, and status'
                              : 'Create a new independent key with initial values',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Body Form
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    // Key Name
                    Text(
                      'Lookup Key Name *',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameController,
                      onChanged: _onNameChanged,
                      validator: (val) => val == null || val.trim().isEmpty ? 'Lookup Key Name is required' : null,
                      decoration: InputDecoration(
                        hintText: 'e.g. Calendar Category, Vehicle Fuel Type',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Key Code (Immutable on Edit)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Key Code (Stable Identifier) *',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF334155),
                          ),
                        ),
                        if (!isEdit)
                          Row(
                            children: [
                              Checkbox(
                                value: _autoCode,
                                activeColor: const Color(0xFF4F46E5),
                                onChanged: (val) => setState(() => _autoCode = val ?? true),
                              ),
                              const Text('Auto-generate', style: TextStyle(fontSize: 12)),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _codeController,
                      readOnly: isEdit || _autoCode,
                      validator: (val) => val == null || val.trim().isEmpty ? 'Key Code is required' : null,
                      style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'e.g. CALENDAR_CATEGORY',
                        filled: isEdit || _autoCode,
                        fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        helperText: isEdit
                            ? 'Key code is permanent so existing ERP modules never break.'
                            : 'Standard uppercase identifier used by modules.',
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Description
                    Text(
                      'Description',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        hintText: 'Brief explanation of this category...',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Icon Selector
                    Text(
                      'Icon Style',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 56,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _iconOptions.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (ctx, idx) {
                          final opt = _iconOptions[idx];
                          final isSel = _selectedIcon == opt['name'];
                          return InkWell(
                            onTap: () => setState(() => _selectedIcon = opt['name']),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              width: 50,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: isSel ? const Color(0xFF4F46E5).withValues(alpha: 0.12) : Colors.transparent,
                                border: Border.all(
                                  color: isSel ? const Color(0xFF4F46E5) : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                                  width: isSel ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    opt['icon'] as IconData,
                                    size: 18,
                                    color: isSel ? const Color(0xFF4F46E5) : (isDark ? Colors.white : const Color(0xFF475569)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    opt['label'] as String,
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                      color: isSel ? const Color(0xFF4F46E5) : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Status & Key Type Row
                    Row(
                      children: [
                        // Status
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Status',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : const Color(0xFF334155),
                                ),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: _status,
                                decoration: InputDecoration(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onChanged: (val) => setState(() => _status = val ?? 'ACTIVE'),
                                items: const [
                                  DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                                  DropdownMenuItem(value: 'INACTIVE', child: Text('Inactive')),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),

                        // Key Type (Only on Create)
                        if (!isEdit)
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Key Type',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : const Color(0xFF334155),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                DropdownButtonFormField<String>(
                                  initialValue: _keyType,
                                  decoration: InputDecoration(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  onChanged: (val) => setState(() => _keyType = val ?? 'CUSTOM'),
                                  items: const [
                                    DropdownMenuItem(value: 'CUSTOM', child: Text('Custom Key')),
                                    DropdownMenuItem(value: 'SYSTEM', child: Text('System Key')),
                                  ],
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),

                    // Initial Values Section (Create Mode Only)
                    if (!isEdit) ...[
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Initial Values (Optional)',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : const Color(0xFF334155),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _addInitialValue,
                            icon: const Icon(Icons.add, size: 14),
                            label: const Text('Add Row', style: TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (_initialValues.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Text(
                            'No initial values added yet. You can add values after creating the key or add a few rows here.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                        )
                      else
                        ...List.generate(_initialValues.length, (idx) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    initialValue: _initialValues[idx]['value_name'],
                                    onChanged: (v) => _initialValues[idx]['value_name'] = v,
                                    decoration: InputDecoration(
                                      hintText: 'Value Name (e.g. Exam)',
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: TextFormField(
                                    initialValue: _initialValues[idx]['value_code'],
                                    onChanged: (v) => _initialValues[idx]['value_code'] = v,
                                    decoration: InputDecoration(
                                      hintText: 'Code (Optional)',
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                    style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.red),
                                  onPressed: () => setState(() => _initialValues.removeAt(idx)),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: state.isSaving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: state.isSaving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(isEdit ? 'Save Changes' : 'Create Key', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
