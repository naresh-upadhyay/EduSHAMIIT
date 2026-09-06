import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/book_models.dart';
import '../../providers/book_provider.dart';

class EditCopyDialog extends ConsumerStatefulWidget {
  final BookModel book;
  final BookCopyModel copy;

  const EditCopyDialog({
    super.key,
    required this.book,
    required this.copy,
  });

  @override
  ConsumerState<EditCopyDialog> createState() => _EditCopyDialogState();
}

class _EditCopyDialogState extends ConsumerState<EditCopyDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _barcodeCtrl;
  late TextEditingController _accessionCtrl;
  late TextEditingController _rackCtrl;
  late TextEditingController _shelfCtrl;
  late TextEditingController _priceCtrl;
  late TextEditingController _supplierCtrl;
  late TextEditingController _notesCtrl;

  late String _selectedStatus;
  late String _selectedCondition;

  @override
  void initState() {
    super.initState();
    final c = widget.copy;
    _barcodeCtrl = TextEditingController(text: c.barcode);
    _accessionCtrl = TextEditingController(text: c.accessionNumber);
    _rackCtrl = TextEditingController(text: c.rack ?? widget.book.rackLocation ?? 'Rack A');
    _shelfCtrl = TextEditingController(text: c.shelf ?? widget.book.shelfLocation ?? 'Shelf 1');
    _priceCtrl = TextEditingController(text: c.purchasePrice.toStringAsFixed(2));
    _supplierCtrl = TextEditingController(text: c.supplier ?? 'Sapna Book House');
    _notesCtrl = TextEditingController(text: c.notes ?? '');

    _selectedStatus = c.status.toUpperCase();
    _selectedCondition = c.condition.toUpperCase();
  }

  @override
  void dispose() {
    _barcodeCtrl.dispose();
    _accessionCtrl.dispose();
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

    final statusOptions = ['AVAILABLE', 'ISSUED', 'MAINTENANCE', 'LOST', 'DAMAGED', 'RESERVED'];
    final statusLabels = {
      'AVAILABLE': 'Available (In Library)',
      'ISSUED': 'Issued / On Loan',
      'MAINTENANCE': 'Under Maintenance / Binding',
      'LOST': 'Lost / Missing',
      'DAMAGED': 'Damaged / Unusable',
      'RESERVED': 'Reserved / On Hold',
    };

    final conditionOptions = state.filterOptions.conditions.isNotEmpty
        ? state.filterOptions.conditions
        : const ['NEW', 'EXCELLENT', 'GOOD', 'FAIR', 'WORN', 'DAMAGED', 'UNDER_REPAIR', 'LOST'];
    const conditionLabels = {
      'NEW': 'New / Mint',
      'EXCELLENT': 'Excellent Condition',
      'GOOD': 'Good Condition',
      'FAIR': 'Fair Condition',
      'WORN': 'Worn Condition',
      'DAMAGED': 'Damaged Condition',
      'UNDER_REPAIR': 'Under Repair',
      'LOST': 'Lost / Missing',
    };


    if (!statusOptions.contains(_selectedStatus)) _selectedStatus = 'AVAILABLE';
    if (!conditionOptions.contains(_selectedCondition)) _selectedCondition = 'GOOD';

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF131B2E) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
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
                  const Icon(Icons.edit_note_rounded, color: Color(0xFF6366F1), size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit Copy #${widget.copy.copyNumber}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
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

            // Form Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Row 1: Barcode & Accession Number
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _barcodeCtrl,
                              label: 'Barcode *',
                              hint: 'e.g. BC-000002-01',
                              isDark: isDark,
                              validator: (v) => v == null || v.trim().isEmpty ? 'Barcode required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _accessionCtrl,
                              label: 'Accession Number *',
                              hint: 'e.g. BK-001',
                              isDark: isDark,
                              validator: (v) => v == null || v.trim().isEmpty ? 'Accession required' : null,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Row 2: Status & Physical Condition
                      Row(
                        children: [
                          Expanded(
                            child: _buildDropdown(
                              label: 'Copy Status *',
                              value: _selectedStatus,
                              items: statusOptions,
                              labels: statusLabels,
                              isDark: isDark,
                              onChanged: (v) => setState(() => _selectedStatus = v!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildDropdown(
                              label: 'Physical Condition *',
                              value: _selectedCondition,
                              items: conditionOptions,
                              labels: conditionLabels,
                              isDark: isDark,
                              onChanged: (v) => setState(() => _selectedCondition = v!),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Row 3: Rack & Shelf Location
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _rackCtrl,
                              label: 'Rack Location',
                              hint: 'e.g. Rack A',
                              isDark: isDark,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _shelfCtrl,
                              label: 'Shelf Location',
                              hint: 'e.g. Shelf 1',
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Row 4: Purchase Price & Supplier
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
                              hint: 'e.g. Sapna Book House',
                              isDark: isDark,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Notes
                      _buildTextField(
                        controller: _notesCtrl,
                        label: 'Copy Notes / Condition Remarks',
                        hint: 'e.g. Minor wear on spine, special edition seal',
                        isDark: isDark,
                        maxLines: 2,
                      ),
                    ],
                  ),
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
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: state.isActionLoading ? null : _submit,
                    child: const Text('Save Copy Changes'),
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
    int maxLines = 1,
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
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: TextStyle(fontSize: 13, color: isDark ? Colors.white : const Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 12.5, color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
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

  Widget _buildDropdown({
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
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
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
      'barcode': _barcodeCtrl.text.trim(),
      'accession_number': _accessionCtrl.text.trim(),
      'status': _selectedStatus,
      'condition': _selectedCondition,
      'rack': _rackCtrl.text.trim(),
      'shelf': _shelfCtrl.text.trim(),
      'location': '${_rackCtrl.text.trim()} - ${_shelfCtrl.text.trim()}',
      'purchase_price': double.tryParse(_priceCtrl.text.trim()) ?? 0.00,
      'supplier': _supplierCtrl.text.trim(),
      'notes': _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : null,
    };

    final success = await notifier.updateBookCopy(widget.copy.id, payload);
    if (success && mounted) {
      Navigator.pop(context);
    }
  }
}
