import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/inventory_models.dart';
import '../../providers/inventory_provider.dart';
import '../inventory_searchable_dropdown.dart';

class IssueStockDialog extends ConsumerStatefulWidget {
  final InventoryItem? preselectedItem;

  const IssueStockDialog({super.key, this.preselectedItem});

  @override
  ConsumerState<IssueStockDialog> createState() => _IssueStockDialogState();
}

class _IssueStockDialogState extends ConsumerState<IssueStockDialog> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedItemId;
  String? _selectedStoreId;
  final _recipientController = TextEditingController();
  final _departmentController = TextEditingController(text: 'Science Laboratory');
  final _qtyController = TextEditingController(text: '5');
  final _purposeController = TextEditingController();
  final _notesController = TextEditingController();
  bool _isReturnable = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.preselectedItem != null) {
      _selectedItemId = widget.preselectedItem!.itemId;
      _selectedStoreId = widget.preselectedItem!.preferredStoreId;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(inventoryProvider.notifier).loadCatalogItems();
    });
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _departmentController.dispose();
    _qtyController.dispose();
    _purposeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(inventoryProvider);
    final metadata = state.metadata;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_selectedStoreId == null && (metadata?.stores.isNotEmpty ?? false)) {
      _selectedStoreId = metadata!.stores.first.storeId;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 580,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.unarchive_outlined, color: Color(0xFFEA580C), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Issue Stock',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Issue items to teacher, classroom or department',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),

            Flexible(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                  // Item selection
                  InventorySearchableDropdown<InventoryItem>(
                    label: 'Select Item',
                    value: _selectedItemId,
                    hint: 'Search item or type new to add...',
                    isRequired: true,
                    items: state.catalogItems.isNotEmpty ? state.catalogItems : state.items,
                    getItemId: (it) => it.itemId,
                    getItemName: (it) => it.name,
                    getItemSubtitle: (it) => 'SKU: ${it.sku} • Available: ${it.currentStock.toInt()} ${it.uomCode}',
                    getItemBadge: (it) => it.category,
                    prefixIcon: Icons.inventory_2_outlined,
                    allowManualEntry: true,
                    quickAddLabel: 'Quick create item & add to catalog & lookups',
                    onChanged: (val) => setState(() => _selectedItemId = val),
                    onQuickAdd: (text) async {
                      final created = await ref.read(inventoryProvider.notifier).quickAddItem(
                        itemName: text,
                        storeId: _selectedStoreId,
                      );
                      return created?.itemId;
                    },
                  ),
                  const SizedBox(height: 14),

                  // Issuing Store & Department
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: InventorySearchableDropdown<InventoryDropdownItem>(
                          label: 'Issuing Store',
                          value: _selectedStoreId,
                          hint: 'Select or add store...',
                          isRequired: true,
                          items: metadata?.stores ?? [],
                          getItemId: (s) => s.storeId,
                          getItemName: (s) => s.storeName,
                          getItemSubtitle: (s) => s.code.isNotEmpty ? 'Code: ${s.code}' : null,
                          prefixIcon: Icons.store_rounded,
                          allowManualEntry: true,
                          quickAddLabel: 'Add store to Lookups & Stores list',
                          onChanged: (val) => setState(() => _selectedStoreId = val),
                          onQuickAdd: (text) async {
                            final added = await ref.read(inventoryProvider.notifier).quickAddLookup(
                              keyCode: 'INVENTORY_STORES',
                              valueName: text,
                              description: 'Quick added store from Issue Stock',
                            );
                            return added?.id ?? added?.code;
                          },
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Department / Room *',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                fontFamily: 'Inter',
                              ),
                            ),
                            const SizedBox(height: 7),
                            TextFormField(
                              controller: _departmentController,
                              decoration: InputDecoration(
                                hintText: 'e.g. Science Lab',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                              validator: (v) => v?.trim().isEmpty ?? true ? 'Required' : null,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Recipient & Quantity
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _recipientController,
                          decoration: InputDecoration(
                            labelText: 'Recipient Name / Staff *',
                            hintText: 'e.g., Prof. Sharma',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          validator: (v) => v?.trim().isEmpty ?? true ? 'Recipient is required' : null,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: TextFormField(
                          controller: _qtyController,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: 'Quantity to Issue *',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          ),
                          validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0 ? 'Enter valid qty' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  TextFormField(
                    controller: _purposeController,
                    decoration: InputDecoration(
                      labelText: 'Purpose of Issue',
                      hintText: 'e.g., Annual Science Exhibition demonstration',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      Checkbox(
                        value: _isReturnable,
                        onChanged: (val) => setState(() => _isReturnable = val ?? false),
                      ),
                      const Expanded(
                        child: Text(
                          'Item is returnable (expect return to inventory)',
                          style: TextStyle(fontSize: 12.5, fontFamily: 'Inter'),
                        ),
                      ),
                    ],
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
                OutlinedButton(
                  onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA580C),
                    foregroundColor: Colors.white,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Confirm Issue'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final payload = {
      'item_id': _selectedItemId,
      'store_id': _selectedStoreId,
      'quantity': double.tryParse(_qtyController.text) ?? 1.0,
      'department': _departmentController.text.trim(),
      'issued_to': _recipientController.text.trim(),
      'purpose': _purposeController.text.trim(),
      'is_returnable': _isReturnable,
      'notes': _notesController.text.trim(),
    };

    final success = await ref.read(inventoryProvider.notifier).issueStock(payload);
    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Stock issued successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to issue stock. Check available quantity.')),
        );
      }
    }
  }
}
