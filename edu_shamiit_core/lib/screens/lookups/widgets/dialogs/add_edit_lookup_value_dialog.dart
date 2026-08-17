import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/lookup_models.dart';
import '../../providers/lookup_provider.dart';

class AddEditLookupValueDialog extends ConsumerStatefulWidget {
  final LookupValueModel? value;

  const AddEditLookupValueDialog({super.key, this.value});

  @override
  ConsumerState<AddEditLookupValueDialog> createState() => _AddEditLookupValueDialogState();
}

class _AddEditLookupValueDialogState extends ConsumerState<AddEditLookupValueDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _codeController;
  late TextEditingController _descController;
  late TextEditingController _sortOrderController;
  String _status = 'ACTIVE';
  bool _autoCode = true;

  @override
  void initState() {
    super.initState();
    final v = widget.value;
    final state = ref.read(lookupProvider);
    final nextSort = state.values.isEmpty ? 1 : state.values.map((val) => val.sortOrder).reduce((a, b) => a > b ? a : b) + 1;

    _nameController = TextEditingController(text: v?.valueName ?? '');
    _codeController = TextEditingController(text: v?.valueCode ?? '');
    _descController = TextEditingController(text: v?.description ?? '');
    _sortOrderController = TextEditingController(text: '${v?.sortOrder ?? nextSort}');
    _status = v?.status ?? 'ACTIVE';
    _autoCode = v == null;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _descController.dispose();
    _sortOrderController.dispose();
    super.dispose();
  }

  void _onNameChanged(String val) {
    if (_autoCode && widget.value == null) {
      final code = val
          .toUpperCase()
          .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
          .replaceAll(RegExp(r'^_+|_+$'), '');
      _codeController.text = code;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final isEdit = widget.value != null;
    final sort = int.tryParse(_sortOrderController.text.trim()) ?? 0;

    final payload = <String, dynamic>{
      'value_name': _nameController.text.trim(),
      'description': _descController.text.trim(),
      'status': _status,
      'sort_order': sort,
    };

    if (!isEdit) {
      payload['value_code'] = _codeController.text.trim().toUpperCase();
    }

    bool success;
    if (isEdit) {
      success = await ref.read(lookupProvider.notifier).updateValue(widget.value!.id, payload);
    } else {
      success = await ref.read(lookupProvider.notifier).addValue(payload);
    }

    if (success && mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEdit ? 'Value updated successfully!' : 'Value added successfully!'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } else if (mounted) {
      final err = ref.read(lookupProvider).errorMessage ?? 'Failed to save value';
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
    final isEdit = widget.value != null;
    final state = ref.watch(lookupProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth < 520 ? screenWidth - 32 : 480.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: Container(
        width: dialogWidth,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF4F46E5), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit ? 'Edit Lookup Value' : 'Add Lookup Value',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'For key: ${state.selectedKey?.keyName ?? ""}',
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
              const SizedBox(height: 20),

              // Value Name
              Text(
                'Value Display Name *',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _nameController,
                onChanged: _onNameChanged,
                validator: (val) => val == null || val.trim().isEmpty ? 'Value name is required' : null,
                decoration: InputDecoration(
                  hintText: 'e.g. Annual Sports Day, Term-1 Exam',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 14),

              // Value Code
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Value Code *',
                    style: TextStyle(
                      fontSize: 12,
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
                        const Text('Auto-generate', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _codeController,
                readOnly: isEdit || _autoCode,
                validator: (val) => val == null || val.trim().isEmpty ? 'Value code is required' : null,
                style: const TextStyle(fontFamily: 'monospace', fontWeight: FontWeight.w600, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'e.g. ANNUAL_SPORTS_DAY',
                  filled: isEdit || _autoCode,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 14),

              // Status & Sort Order
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
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          initialValue: _status,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
                  const SizedBox(width: 12),

                  // Sort Order
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sort Order',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _sortOrderController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: '1, 2, 3...',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Description
              Text(
                'Description (Optional)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _descController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: 'Optional notes for this lookup value...',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(
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
                  const SizedBox(width: 10),
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
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text(isEdit ? 'Save Changes' : 'Add Value', style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
