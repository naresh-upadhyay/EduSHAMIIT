import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/book_models.dart';
import '../../providers/book_provider.dart';

class AddCopyDialog extends ConsumerStatefulWidget {
  final BookModel book;
  const AddCopyDialog({super.key, required this.book});

  @override
  ConsumerState<AddCopyDialog> createState() => _AddCopyDialogState();
}

class _AddCopyDialogState extends ConsumerState<AddCopyDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _copiesCountCtrl;
  late TextEditingController _prefixCtrl;
  late TextEditingController _rackCtrl;
  late TextEditingController _shelfCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _supplierCtrl;
  late TextEditingController _notesCtrl;

  String _selectedCondition = 'GOOD';

  @override
  void initState() {
    super.initState();
    _copiesCountCtrl = TextEditingController(text: '1');
    _prefixCtrl = TextEditingController();
    _rackCtrl = TextEditingController(text: widget.book.rackLocation ?? 'Rack A');
    _shelfCtrl = TextEditingController(text: widget.book.shelfLocation ?? 'Shelf 1');
    _priceCtrl = TextEditingController(text: '299.00');
    _supplierCtrl = TextEditingController(text: 'Sapna Book House');
    _notesCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _copiesCountCtrl.dispose();
    _prefixCtrl.dispose();
    _rackCtrl.dispose();
    _shelfCtrl.dispose();
    _priceCtrl.dispose();
    _supplierCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = ref.watch(bookProvider);

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.add_to_photos_rounded, color: Color(0xFF6366F1), size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add Physical Copies',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          widget.book.title,
                          style: TextStyle(fontSize: 12, color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Body Form
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _copiesCountCtrl,
                            label: 'Number of Copies to Add',
                            hint: '1',
                            keyboardType: TextInputType.number,
                            isDark: isDark,
                            validator: (v) {
                              final num = int.tryParse(v ?? '');
                              if (num == null || num < 1 || num > 50) {
                                return 'Enter 1 to 50';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDropdownField(
                            label: 'Copy Condition',
                            value: _selectedCondition,
                            items: state.filterOptions.conditions.isNotEmpty
                                ? state.filterOptions.conditions
                                : const ['NEW', 'EXCELLENT', 'GOOD', 'FAIR', 'WORN', 'DAMAGED', 'UNDER_REPAIR', 'LOST'],
                            labels: const {
                              'NEW': 'New / Mint',
                              'EXCELLENT': 'Excellent Condition',
                              'GOOD': 'Good Condition',
                              'FAIR': 'Fair Condition',
                              'WORN': 'Worn Condition',
                              'DAMAGED': 'Damaged Condition',
                              'UNDER_REPAIR': 'Under Repair',
                              'LOST': 'Lost / Missing',
                            },
                            isDark: isDark,
                            onChanged: (val) {
                              if (val != null) setState(() => _selectedCondition = val);
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _rackCtrl,
                            label: 'Rack Location',
                            hint: 'Rack A',
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _shelfCtrl,
                            label: 'Shelf Location',
                            hint: 'Shelf 1',
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _priceCtrl,
                            label: 'Purchase Price (₹)',
                            hint: '299.00',
                            isDark: isDark,
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _supplierCtrl,
                            label: 'Supplier',
                            hint: 'Sapna Book House',
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _notesCtrl,
                      label: 'Notes / Copy Remarks',
                      hint: 'Optional procurement notes...',
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0)),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    onPressed: state.isActionLoading ? null : _submit,
                    child: const Text('Add Copies'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 13, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
            filled: true,
            fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required Map<String, String> labels,
    required bool isDark,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(labels[e] ?? e))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(bookProvider.notifier);

    final payload = {
      'number_of_copies': int.parse(_copiesCountCtrl.text.trim()),
      'condition': _selectedCondition,
      'rack': _rackCtrl.text.trim(),
      'shelf': _shelfCtrl.text.trim(),
      'purchase_price': double.tryParse(_priceCtrl.text.trim()) ?? 299.0,
      'supplier': _supplierCtrl.text.trim(),
      'notes': _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
    };

    final success = await notifier.addBookCopies(widget.book.id, payload);
    if (success && mounted) {
      Navigator.pop(context);
    }
  }
}
